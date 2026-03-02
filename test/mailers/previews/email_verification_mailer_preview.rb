class EmailVerificationMailerPreview < ActionMailer::Preview
  def verify_email
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    verification_request = EmailVerificationRequest.new(
      user: user,
      email: "newemail@example.com",
      token: "preview-verification-token",
      expires_at: 30.minutes.from_now
    )

    EmailVerificationMailer.verify_email(verification_request)
  end
end
