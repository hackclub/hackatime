class OnboardingMailer < ApplicationMailer
  layout false

  def check_in(user, recipient_email:)
    @user = user

    mail(
      to: recipient_email,
      from: "Mahad from Hackatime <mahad@hackclub.com>",
      subject: "How are you finding Hackatime?"
    )
  end
end
