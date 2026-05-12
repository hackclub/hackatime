class OnboardingMailerPreview < ActionMailer::Preview
  def check_in
    user = User.first || User.new(username: "preview_user", timezone: "UTC")

    OnboardingMailer.check_in(user, recipient_email: "user@example.com")
  end
end
