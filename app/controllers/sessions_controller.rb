class SessionsController < ApplicationController
  HCA_AUTHENTICATION_MAX_AGE = 30.minutes

  rescue_from OauthAuthentication::HcaIdentityConflictError, with: :handle_hca_identity_conflict

  def hca_new = failure

  def hca_create
    auth = request.env["omniauth.auth"]
    info = auth&.dig("info") || {}
    claims = auth&.dig("extra", "raw_info") || {}
    subject = auth&.dig("uid").to_s
    email = (claims["email"] || info["email"]).to_s.strip.downcase
    verified = claims["email_verified"] == true || info["email_verified"] == true
    continuation = safe_return_url(request.env.dig("omniauth.params", "continue"))
    return failure unless auth&.dig("provider") == "hca" && verified && subject.match?(/\Aident![A-Za-z0-9_-]+\z/) && email.present?

    identity = { "subject" => subject, "email" => email, "slack_uid" => claims["slack_id"].presence, "created_at" => Time.current.to_i, "continue" => continuation }.compact
    user = User.from_hca_identity(subject:, email:, slack_uid: identity["slack_uid"])
    return establish_hca_session(user, continuation:) if user

    session[:pending_hca] = identity
    redirect_to signin_path, notice: "Choose how to finish setting up your Hackatime account."
  end

  def hca_account
    pending = pending_hca_identity
    return failure unless pending

    user = User.create_from_hca_identity!(subject: pending["subject"], email: pending["email"], slack_uid: pending["slack_uid"], country_code: User.country_code_from_ip(client_ip))
    establish_hca_session(user, continuation: pending["continue"], onboarding: true)
  end

  def hca_recovery
    pending = pending_hca_identity
    if pending && (email_address = EmailAddress.find_by("LOWER(email) = ?", params[:email].to_s.strip.downcase)) && !email_address.source_preserved_for_deletion? && email_address.user.authentication_allowed? && email_address.user.hca_id.blank? && email_address.user.admin_level == "default" && !email_address.user.pending_deletion?
      token = email_address.user.sign_in_tokens.create!(auth_type: :hca_recovery, return_data: { "hca_subject" => pending["subject"] })
      LoopsMailer.hca_recovery_email(email_address.email, token.token).deliver_later
    end
    redirect_to signin_path, notice: "If that account is eligible, we've sent recovery instructions."
  end

  def hca_cancel
    session.delete(:pending_hca)
    redirect_to signin_path
  end

  def slack_new
    pending = pending_hca_identity
    purpose = pending ? "recovery" : "integration"
    return redirect_to(signin_path, alert: "Sign in with Hack Club Account again first.") if purpose == "integration" && !recent_hca_authentication?

    redirect_uri = url_for(action: :slack_create, only_path: false)
    oauth_nonce = SecureRandom.hex(24)
    state_payload = {
      token: oauth_nonce,
      purpose: purpose,
      user_id: (current_user.id if purpose == "integration")
    }.to_json
    session[:slack_oauth_state] = state_payload

    Rails.logger.info "Starting Slack OAuth flow with redirect URI: #{redirect_uri}"
    redirect_to User.slack_authorize_url(redirect_uri, state: state_payload),
                host: "https://slack.com",
                allow_other_host: "https://slack.com"
  end

  def slack_create
    return if handle_oauth_error("Slack", redirect_path: root_path, alert_label: "Slack")

    redirect_uri = url_for(action: :slack_create, only_path: false)
    unless valid_oauth_state?(provider: "Slack", session_key: :slack_oauth_state, received_nonce: params[:state])
      return redirect_to(root_path, alert: "Failed to authenticate with Slack")
    end
    slack_state = parse_slack_state(params[:state])
    return failure unless slack_state

    identity = User.exchange_slack_code(params[:code], redirect_uri)
    return failure unless identity

    if slack_state["purpose"] == "integration"
      return failure unless current_user&.id == slack_state["user_id"].to_i && recent_hca_authentication?
      return failure unless User.connect_slack_identity!(current_user, identity)
      redirect_to my_settings_path, notice: "Successfully re-authorised Slack."
    else
      pending = pending_hca_identity
      user = User.find_by(slack_uid: identity[:uid])
      return failure unless pending && user
      bind_recovered_hca!(user, pending, proven_slack_uid: identity[:uid])
      establish_hca_session(user, continuation: pending["continue"])
    end
  end

  def failure
    redirect_to signin_path, alert: "Authentication failed. Please try again."
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
    redirect_to signin_path(
      login_hint: params[:email].to_s.strip.downcase.presence,
      continue: safe_return_url(params[:continue])
    ), notice: "Email sign-in has moved to Hack Club Account."
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

    return redirect_to(root_path, alert: "Invalid or expired link") unless valid_token&.hca_recovery?

    pending = pending_hca_identity
    return redirect_to(signin_path, alert: "Restart recovery in this browser.") unless pending && valid_token.return_data&.dig("hca_subject") == pending["subject"]
    return redirect_to(signin_path, alert: "This recovery link has expired or was already used.") unless consume_hca_recovery_token!(valid_token, pending)

    establish_hca_session(valid_token.user, continuation: pending["continue"])
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
    session[:impersonater_authentication_version] ||= current_user.authentication_version
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
    redirect_to root_path, notice: "Impersonating #{user.display_name}"
  end

  def stop_impersonating
    session[:user_id] = session[:impersonater_user_id]
    session[:authentication_version] = session[:impersonater_authentication_version]
    session[:impersonater_user_id] = nil
    session[:impersonater_authentication_version] = nil
    redirect_to root_path, notice: "Stopped impersonating"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out!"
  end

  private

  def client_ip = request.headers["CF-Connecting-IP"].presence || request.remote_ip

  def pending_hca_identity
    pending = session[:pending_hca]
    unless pending.is_a?(Hash) && pending["created_at"].to_i > 10.minutes.ago.to_i
      session.delete(:pending_hca)
      return
    end

    pending
  end

  def recent_hca_authentication?
    current_user.present? &&
      session[:auth_provider] == "hca" &&
      session[:authenticated_at].to_i > HCA_AUTHENTICATION_MAX_AGE.ago.to_i
  end

  def consume_hca_recovery_token!(token, pending)
    SignInToken.transaction do
      token.lock!
      return false if token.used_at? || token.expires_at <= Time.current || token.return_data&.dig("hca_subject") != pending["subject"]

      bind_recovered_hca!(token.user, pending)
      token.mark_used!
    end
    true
  end

  def establish_hca_session(user, continuation: nil, onboarding: false)
    return failure unless user&.authentication_allowed?

    return_data = build_return_data(continuation)
    reset_session
    session[:user_id] = user.id
    session[:authentication_version] = user.authentication_version
    session[:auth_provider] = "hca"
    session[:authenticated_at] = Time.current.to_i
    session[:return_data] = return_data if return_data.present?
    return redirect_to(setup_path, notice: "Account created successfully.") if onboarding
    return redirect_to(continuation, notice: "Successfully signed in!") if safe_return_url(continuation) # codeql[rb/url-redirection]

    redirect_to root_path, notice: "Successfully signed in!"
  end

  def bind_recovered_hca!(user, pending, proven_slack_uid: nil)
    User.transaction do
      user.lock!
      subject_owner = User.lock.find_by(hca_id: pending["subject"])
      email_owner = EmailAddress.lock.find_by("LOWER(email) = ?", pending["email"])&.user
      claim_slack_owner = User.lock.find_by(slack_uid: pending["slack_uid"]) if pending["slack_uid"].present?
      conflicting_claim = [ subject_owner, email_owner, claim_slack_owner ].compact.any? { |owner| owner != user }
      slack_proof_mismatch = proven_slack_uid.present? && pending["slack_uid"].present? && proven_slack_uid != pending["slack_uid"]
      if !user.authentication_allowed? || user.hca_id.present? && user.hca_id != pending["subject"] || user.admin_level != "default" || user.pending_deletion? || conflicting_claim || slack_proof_mismatch
        User.raise_hca_conflict!(subject: pending["subject"], reason: "recovery_conflict", email_user: email_owner, slack_user: claim_slack_owner)
      end

      attributes = { hca_id: pending["subject"], hca_access_token: nil, hca_scopes: [] }
      attributes[:slack_uid] = proven_slack_uid if proven_slack_uid.present? && User.where(slack_uid: proven_slack_uid).where.not(id: user.id).none?
      user.update!(attributes)
      User.attach_hca_email!(user, pending["email"])
    end
  end

  def handle_hca_identity_conflict(error)
    HCAIdentityConflict.record!(error)
    redirect_to signin_path, alert: "We couldn't safely link this Hack Club Account. Please contact support."
  end

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
