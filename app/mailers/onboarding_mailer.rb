class OnboardingMailer < ApplicationMailer
  layout false

  def welcome(user, recipient_email:)
    @user = user
    mail(
      to: recipient_email,
      subject: "Welcome to Hackatime!"
    )
  end

  def check_in(user, recipient_email:)
    @user = user
    from_email = ENV.fetch("ONBOARDING_CHECK_IN_FROM_EMAIL", "Mahad from Hackatime <mahad@hackclub.com>")
    reply_to = "hackatime@hackclub.com"

    mail(
      to: recipient_email,
      from: from_email,
      cc: from_email,
      reply_to:,
      subject: "How are you finding Hackatime?"
    )
  end
end
