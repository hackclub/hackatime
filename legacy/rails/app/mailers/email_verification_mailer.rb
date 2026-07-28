class EmailVerificationMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.email_verification_mailer.verify_email.subject
  #
  def verify_email(verification_request)
    @verification_request = verification_request
    @user = verification_request.user
    @verification_url = auth_token_url(verification_request.token)

    mail(
      to: verification_request.email,
      subject: "Verify your email address for Hackatime"
    )
  end
end
