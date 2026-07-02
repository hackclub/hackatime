class SessionsController < ApplicationController
  def hca_new
    session[:return_data] = build_return_data(params[:continue]) if params[:continue].present?
    Rails.logger.info("Sessions return data: #{session[:return_data]}")
    redirect_uri = url_for(action: :hca_create, only_path: false)

    redirect_to User.hca_authorize_url(redirect_uri),
      host: "https://auth.hackclub.com",
      allow_other_host: "https://auth.hackclub.com"
  end

  def hca_create
    return if handle_oauth_error("HCA", redirect_path: root_path, alert_label: "Hack Club Auth")

    redirect_uri = url_for(action: :hca_create, only_path: false)
    @user = User.from_hca_token(params[:code], redirect_uri, client_ip)

    if @user&.persisted?
      preserved_return_data = session[:return_data]
      reset_session
      session[:user_id] = @user.id
      session[:return_data] = preserved_return_data if preserved_return_data
      notice = "Successfully signed in with Hack Club Auth! Welcome!"

      if @user.previously_new_record?
        redirect_to setup_path, notice: notice
      elsif session[:return_data]&.dig("url").present?
        redirect_to session[:return_data].delete("url"), notice: notice
      else
        redirect_to root_path, notice: notice
      end
    else
      redirect_to root_path, alert: "Failed to authenticate with Hack Club Auth!"
    end
  end

  def slack_new
    redirect_uri = url_for(action: :slack_create, only_path: false)
    oauth_nonce = SecureRandom.hex(24)
    session[:slack_oauth_state_nonce] = oauth_nonce
    state_payload = {
      token: oauth_nonce,
      close_window: params[:close_window].present?,
      continue: params[:continue]
    }.to_json

    Rails.logger.info "Starting Slack OAuth flow with redirect URI: #{redirect_uri}"
    redirect_to User.slack_authorize_url(redirect_uri, state: state_payload),
                host: "https://slack.com",
                allow_other_host: "https://slack.com"
  end

  def slack_create
    return if handle_oauth_error("Slack", redirect_path: root_path, alert_label: "Slack")

    redirect_uri = url_for(action: :slack_create, only_path: false)
    slack_state = parse_slack_state(params[:state])
    unless valid_oauth_state?(provider: "Slack", session_key: :slack_oauth_state_nonce, received_nonce: slack_state&.dig("token"))
      return redirect_to(root_path, alert: "Failed to authenticate with Slack")
    end

    @user = User.from_slack_token(params[:code], redirect_uri, client_ip)

    if @user&.persisted?
      reset_session
      session[:user_id] = @user.id
      notice = "Successfully signed in with Slack! Welcome!"

      continue_url = safe_return_url(slack_state&.dig("continue").presence)

      if slack_state&.dig("close_window")
        redirect_to close_window_path
      elsif @user.previously_new_record?
        session[:return_data] = build_return_data(continue_url)
        redirect_to setup_path, notice: notice
      elsif continue_url.present?
        redirect_to continue_url, notice: notice # codeql[rb/url-redirection]
      else
        redirect_to root_path, notice: notice
      end
    else
      report_message("Failed to create/update user from Slack data")
      redirect_to root_path, alert: "Failed to sign in with Slack"
    end
  end

  def close_window = render(:close_window, layout: false)

  def github_new
    return unless require_signed_in!("Please sign in first to link your GitHub account")

    redirect_uri = url_for(action: :github_create, only_path: false)
    oauth_nonce = SecureRandom.hex(24)
    session[:github_oauth_state_nonce] = oauth_nonce
    Rails.logger.info "Starting GitHub OAuth flow with redirect URI: #{redirect_uri}"
    redirect_to User.github_authorize_url(redirect_uri, state: oauth_nonce),
                allow_other_host: "https://github.com"
  end

  def github_create
    return unless require_signed_in!("Please sign in first to link your GitHub account")

    redirect_uri = url_for(action: :github_create, only_path: false)

    if params[:error].present?
      report_message("GitHub OAuth error: #{params[:error]}")
      return redirect_to(my_settings_path, alert: "Failed to authenticate with GitHub. Error ID: #{Sentry.last_event_id}")
    end

    unless valid_oauth_state?(provider: "GitHub", session_key: :github_oauth_state_nonce, received_nonce: params[:state])
      return redirect_to(my_settings_path, alert: "Failed to link GitHub account")
    end

    @user = User.from_github_token(params[:code], redirect_uri, current_user)

    if @user&.persisted?
      redirect_to my_settings_path, notice: "Successfully linked GitHub account!"
    else
      report_message("Failed to link GitHub account")
      redirect_to my_settings_path, alert: "Failed to link GitHub account"
    end
  end

  def github_unlink
    return unless require_signed_in!("Please sign in first")

    current_user.update!(github_access_token: nil, github_uid: nil, github_username: nil)
    Rails.logger.info "GitHub account unlinked for User ##{current_user.id}"
    redirect_to my_settings_path, notice: "GitHub account unlinked successfully"
  end

  def email
    email = params[:email].downcase
    continue_param = params[:continue]

    if Rails.env.production?
      HandleEmailSigninJob.perform_later(email, continue_param, client_ip)
    else
      token = HandleEmailSigninJob.perform_now(email, continue_param, client_ip)
      session[:dev_magic_link] = auth_token_url(token)
    end

    redirect_path = params[:redirect_to] == "signin" ? signin_path(sign_in_email: true) : root_path(sign_in_email: true)
    redirect_to redirect_path, notice: "Check your email for a sign-in link!"
  end

  def add_email
    return unless require_signed_in!("Please sign in first to add an email")

    email = params[:email].downcase
    conflict =
      ("#{email} is already linked to an account." if EmailAddress.exists?(email: email)) ||
      ("#{email} already has a pending verification — check your inbox, or use \"Resend\" to get a new link." if EmailVerificationRequest.kept.exists?(email: email))
    return redirect_to(my_settings_path, alert: conflict) if conflict

    verification_request = current_user.email_verification_requests.create!(email: email)
    mailer = EmailVerificationMailer.verify_email(verification_request)
    Rails.env.production? ? mailer.deliver_later : mailer.deliver_now

    redirect_to my_settings_path, notice: "Verification email sent — check #{email} to confirm it."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to my_settings_path, alert: "Couldn't add #{email}: #{e.record.errors.full_messages.join(', ')}."
  end

  def resend_email_verification
    return unless require_signed_in!("Please sign in first to resend a verification email.")

    email = params[:email].to_s.downcase
    verification_request = current_user.email_verification_requests.kept.find_by(email: email)

    unless verification_request
      redirect_to my_settings_path, alert: "There's no pending verification for #{email}. Try adding the email again."
      return
    end

    unless verification_request.resend_available?
      cooldown_minutes = (verification_request.resend_cooldown_seconds / 60.0).ceil
      redirect_to my_settings_path,
                  alert: "We just sent a verification email — you can resend it in #{cooldown_minutes} minute#{'s' unless cooldown_minutes == 1}."
      return
    end

    verification_request.refresh_for_resend!

    mailer = EmailVerificationMailer.verify_email(verification_request)
    Rails.env.production? ? mailer.deliver_later : mailer.deliver_now

    redirect_to my_settings_path, notice: "Verification email resent — check #{email} to confirm it."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to my_settings_path, alert: "Couldn't resend the verification email: #{e.record.errors.full_messages.join(', ')}."
  end

  def unlink_email
    return unless require_signed_in!("Please sign in first to unlink an email")

    email = params[:email].downcase
    email_record = current_user.email_addresses.find_by(email: email)

    unless email_record
      pending_request = current_user.email_verification_requests.kept.find_by(email: email)
      return redirect_to(my_settings_path, alert: "#{email} isn't linked to your account.") unless pending_request

      pending_request.soft_delete!
      return redirect_to(my_settings_path, notice: "Removed the pending verification for #{email}.")
    end

    unless current_user.can_delete_email_address?(email_record)
      return redirect_to(my_settings_path, alert: "You can only unlink emails that are used for signing in.")
    end

    email_verification_request = current_user.email_verification_requests.find_by(email: email)

    email_record.destroy!
    email_verification_request&.soft_delete!

    redirect_to my_settings_path, notice: "Unlinked #{email} from your account."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to my_settings_path, alert: "Couldn't unlink #{email}: #{e.record.errors.full_messages.join(', ')}."
  end

  def token
    verification_request = EmailVerificationRequest.valid.find_by(token: params[:token])

    if verification_request
      verification_request.verify!
      redirect_to my_settings_path, notice: "Successfully verified your email address!"
      return
    end

    valid_token = SignInToken.where(token: params[:token], used_at: nil)
                            .where("expires_at > ?", Time.current).first

    if valid_token
      valid_token.mark_used!
      reset_session
      session[:user_id] = valid_token.user_id
      continue_url = safe_return_url(valid_token.continue_param)
      session[:return_data] = (valid_token.return_data || {}).merge(build_return_data(continue_url))
      if continue_url.present?
        redirect_to continue_url, notice: "Successfully signed in!" # codeql[rb/url-redirection]
      else
        redirect_to root_path, notice: "Successfully signed in!"
      end
    else
      redirect_to root_path, alert: "Invalid or expired link"
    end
  end

  def impersonate
    return unless require_admin!(alert: "You are not authorized to impersonate users")

    user = User.find_by(id: params[:id])
    return redirect_to(root_path, alert: "who?") unless user

    actor_level = current_user.admin_level
    target_level = user.admin_level
    blocked =
      target_level == "ultraadmin" ||
      (target_level == "superadmin" && actor_level != "ultraadmin") ||
      (target_level == "admin" && !actor_level.in?(%w[superadmin ultraadmin]))
    return redirect_to(root_path, alert: "nice try, you cant do that") if blocked

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
    reset_session
    redirect_to root_path, notice: "Signed out!"
  end

  private

  def client_ip = request.headers["CF-Connecting-IP"].presence || request.remote_ip

  def parse_slack_state(raw_state)
    JSON.parse(raw_state)
  rescue JSON::ParserError, TypeError
    nil
  end

  def valid_oauth_state?(provider:, session_key:, received_nonce:)
    expected_nonce = session.delete(session_key)

    if expected_nonce.blank? || received_nonce.blank?
      report_message("#{provider} OAuth state missing expected=#{expected_nonce.present?} received=#{received_nonce.present?}")
      return false
    end

    return true if ActiveSupport::SecurityUtils.secure_compare(received_nonce.to_s, expected_nonce.to_s)

    report_message("#{provider} OAuth state mismatch")
    false
  end

  # Handles OAuth callback errors. Returns true if a redirect was performed.
  def handle_oauth_error(provider, redirect_path:, alert_label:)
    return false if params[:error].blank?

    if params[:error] == "access_denied"
      redirect_to redirect_path, alert: "Sign in cancelled"
      return true
    end

    report_message("#{provider} OAuth error: #{params[:error]}")
    redirect_to redirect_path, alert: "Failed to authenticate with #{alert_label}. Error ID: #{Sentry.last_event_id}"
    true
  end
end
