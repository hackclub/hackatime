class OnboardingMailer < ApplicationMailer
  layout false

  def check_in(user, recipient_email:)
    @user = user
    from_email = ENV.fetch("ONBOARDING_CHECK_IN_FROM_EMAIL", "Mahad from Hackatime <mahad@hackclub.com>")

    mail(
      to: recipient_email,
      from: from_email,
      cc: from_email,
      subject: "How are you finding Hackatime?"
    )
  end
end
