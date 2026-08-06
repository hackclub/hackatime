class LoopsMailer < ApplicationMailer
  def sign_in_email(email, token)
    @email = email
    @token = token
    @sign_in_url = auth_token_url(@token)

    mail(
      to: @email,
      subject: "Your Hackatime sign-in link"
    )
  end

  def hca_recovery_email(email, token)
    @recovery_url = auth_token_url(token)
    mail(to: email, subject: "Recover your Hackatime account")
  end
end
