class SessionsController < ApplicationController
  def hca_new
    session[:return_data] = { "url" => safe_return_url(params[:continue].presence) } if params[:continue].present?
    Rails.logger.info("Sessions return data: #{session[:return_data]}")
    redirect_uri = url_for(action: :hca_create, only_path: false)

    redirect_to User.hca_authorize_url(redirect_uri),
      host: "https://auth.hackclub.com",
      allow_other_host: "https://auth.hackclub.com"
  end

  def hca_create
    if params[:error].present?
      if params[:error] == "access_denied"
        redirect_to root_path, alert: "Sign in cancelled"
        return
      end

      Rails.logger.error "HCA OAuth error: #{params[:error]}"
      Sentry.capture_message("HCA OAuth error: #{params[:error]}")
      redirect_to root_path, alert: "Failed to authenticate with Hack Club Auth. Error ID: #{Sentry.last_event_id}"
      return
    end

    redirect_uri = url_for(action: :hca_create, only_path: false)

    @user = User.from_hca_token(params[:code], redirect_uri)

    if @user&.persisted?
      session[:user_id] = @user.id

      if @user.data_migration_jobs.empty?
        MigrateUserFromHackatimeJob.perform_later(@user.id)
      end

      if !@user.heartbeats.exists?
        # User hasn't set up editor yet; preserve return_data already set by hca_new,
        # only override if a new continue param is provided.
        if params[:continue].present?
          session[:return_data] = { "url" => safe_return_url(params[:continue].presence) }
        end
        Rails.logger.info("Sessions return data: #{session[:return_data]}")
        redirect_to my_wakatime_setup_path, notice: "Successfully signed in with Hack Club Auth! Welcome!"
      elsif session[:return_data]&.dig("url").present?
        return_url = session[:return_data].delete("url")
        redirect_to return_url, notice: "Successfully signed in with Hack Club Auth! Welcome!"
      else
        redirect_to root_path, notice: "Successfully signed in with Hack Club Auth! Welcome!"
      end
    else
      redirect_to root_path, alert: "Failed to authenticate with Hack Club Auth!"
    end
  end

  def slack_new
    redirect_uri = url_for(action: :slack_create, only_path: false)
    Rails.logger.info "Starting Slack OAuth flow with redirect URI: #{redirect_uri}"
    redirect_to User.slack_authorize_url(redirect_uri, close_window: params[:close_window].present?, continue_param: params[:continue]),
                host: "https://slack.com",
                allow_other_host: "https://slack.com"
  end

  def slack_create
    redirect_uri = url_for(action: :slack_create, only_path: false)

    if params[:error].present?
      if params[:error] == "access_denied"
        redirect_to root_path, alert: "Sign in cancelled"
        return
      end

      Rails.logger.error "Slack OAuth error: #{params[:error]}"
      Sentry.capture_message("Slack OAuth error: #{params[:error]}")
      redirect_to root_path, alert: "Failed to authenticate with Slack. Error ID: #{Sentry.last_event_id}"
      return
    end

    @user = User.from_slack_token(params[:code], redirect_uri)

    if @user&.persisted?
      session[:user_id] = @user.id

      if @user.data_migration_jobs.empty?
        # if they don't have a data migration job, add one to the queue
        MigrateUserFromHackatimeJob.perform_later(@user.id)
      end

      state = JSON.parse(params[:state]) rescue {}
      if state["close_window"]
        redirect_to close_window_path
      elsif !@user.heartbeats.exists?
        session[:return_data] = { "url" => safe_return_url(state["continue"].presence) }
        redirect_to my_wakatime_setup_path, notice: "Successfully signed in with Slack! Welcome!"
      elsif (continue_url = safe_return_url(state["continue"].presence))
        redirect_to continue_url, notice: "Successfully signed in with Slack! Welcome!"
      else
        redirect_to root_path, notice: "Successfully signed in with Slack! Welcome!"
      end
    else
      Rails.logger.error "Failed to create/update user from Slack data"
      redirect_to root_path, alert: "Failed to sign in with Slack"
    end
  end

  def close_window
    render :close_window, layout: false
  end

  def github_new
    unless current_user
      redirect_to root_path, alert: "Please sign in first to link your GitHub account"
      return
    end

    redirect_uri = url_for(action: :github_create, only_path: false)
    Rails.logger.info "Starting GitHub OAuth flow with redirect URI: #{redirect_uri}"
    redirect_to User.github_authorize_url(redirect_uri),
                allow_other_host: "https://github.com"
  end

  def github_create
    unless current_user
      redirect_to root_path, alert: "Please sign in first to link your GitHub account"
      return
    end

    redirect_uri = url_for(action: :github_create, only_path: false)

    if params[:error].present?
      Rails.logger.error "GitHub OAuth error: #{params[:error]}"
      Sentry.capture_message("GitHub OAuth error: #{params[:error]}")
      redirect_to my_settings_path, alert: "Failed to authenticate with GitHub. Error ID: #{Sentry.last_event_id}"
      return
    end

    @user = User.from_github_token(params[:code], redirect_uri, current_user)

    if @user&.persisted?
      redirect_to my_settings_path, notice: "Successfully linked GitHub account!"
    else
      Rails.logger.error "Failed to link GitHub account"
      redirect_to my_settings_path, alert: "Failed to link GitHub account"
    end
  end

  def github_unlink
    unless current_user
      redirect_to root_path, alert: "Please sign in first"
      return
    end

    current_user.update!(github_access_token: nil, github_uid: nil, github_username: nil)
    Rails.logger.info "GitHub account unlinked for User ##{current_user.id}"
    redirect_to my_settings_path, notice: "GitHub account unlinked successfully"
  end

  def email
    email = params[:email].downcase
    continue_param = params[:continue]

    if Rails.env.production?
      HandleEmailSigninJob.perform_later(email, continue_param)
    else
      token = HandleEmailSigninJob.perform_now(email, continue_param)
      session[:dev_magic_link] = auth_token_url(token)
    end

    redirect_to root_path(sign_in_email: true), notice: "Check your email for a sign-in link!"
  end

  def add_email
    unless current_user
      redirect_to root_path, alert: "Please sign in first to add an email"
      return
    end

    email = params[:email].downcase

    if EmailAddress.exists?(email: email)
      redirect_to my_settings_path, alert: "This email is already associated with an account"
      return
    end

    if EmailVerificationRequest.exists?(email: email)
      redirect_to my_settings_path, alert: "This email is already pending verification"
      return
    end

    verification_request = current_user.email_verification_requests.create!(
      email: email
    )

    if Rails.env.production?
      EmailVerificationMailer.verify_email(verification_request).deliver_later
    else
      EmailVerificationMailer.verify_email(verification_request).deliver_now
    end

    redirect_to my_settings_path, notice: "Check your email to verify the new address!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to my_settings_path, alert: "Failed to add email: #{e.record.errors.full_messages.join(', ')}"
  end

  def unlink_email
    unless current_user
      redirect_to root_path, alert: "Please sign in first to unlink an email"
      return
    end

    email = params[:email].downcase

    email_record = current_user.email_addresses.find_by(
      email: email
    )

    unless email_record
      redirect_to my_settings_path, alert: "Email must exist to be unlinked"
      return
    end

    unless current_user.can_delete_email_address?(email_record)
      redirect_to my_settings_path, alert: "Email must be registered for signing in to unlink"
      return
    end

    email_verification_request = current_user.email_verification_requests.find_by(
      email: email
    )

    email_record.destroy!
    email_verification_request&.destroy

    redirect_to my_settings_path, notice: "Email unlinked!"
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to my_settings_path, alert: "Failed to unlink email: #{e.record.errors.full_messages.join(', ')}"
  end

  def token
    verification_request = EmailVerificationRequest.valid.find_by(token: params[:token])

    if verification_request
      verification_request.verify!
      redirect_to my_settings_path, notice: "Successfully verified your email address!"
      return
    end

    # If no verification request found, try the old sign-in token system
    valid_token = SignInToken.where(token: params[:token], used_at: nil)
                            .where("expires_at > ?", Time.current)
                            .first

    if valid_token
      valid_token.mark_used!
      session[:user_id] = valid_token.user_id
      session[:return_data] = valid_token.return_data || {}
      user = User.find(valid_token.user_id)
      continue_url = safe_return_url(valid_token.continue_param)

      if !user.heartbeats.exists?
        # User hasn't set up editor yet; send through wakatime setup first
        session[:return_data]["url"] = continue_url if continue_url.present?
        redirect_to my_wakatime_setup_path, notice: "Successfully signed in!"
      elsif continue_url.present?
        redirect_to continue_url, notice: "Successfully signed in!"
      else
        redirect_to root_path, notice: "Successfully signed in!"
      end
    else
      redirect_to root_path, alert: "Invalid or expired link"
    end
  end

  def impersonate
    unless current_user && current_user.admin_level.in?([ "admin", "superadmin" ])
      redirect_to root_path, alert: "You are not authorized to impersonate users"
      return
    end

    user = User.find_by(id: params[:id])
    unless user
      redirect_to root_path, alert: "who?"
      return
    end

    if user.admin_level == "superadmin"
      redirect_to root_path, alert: "nice try, you cant do that"
      return
    end
    if user.admin_level == "admin" && current_user.admin_level != "superadmin"
      redirect_to root_path, alert: "nice try, you cant do that"
      return
    end

    session[:impersonater_user_id] ||= current_user.id
    session[:user_id] = user.id
    redirect_to root_path, notice: "Impersonating #{user.display_name}"
  end

  def stop_impersonating
    session[:user_id] = session[:impersonater_user_id]
    session[:impersonater_user_id] = nil
    redirect_to root_path, notice: "Stopped impersonating"
  end

  def destroy
    session[:user_id] = nil
    session[:impersonater_user_id] = nil
    redirect_to root_path, notice: "Signed out!"
  end
end
