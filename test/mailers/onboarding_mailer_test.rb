require "test_helper"

class OnboardingMailerTest < ActionMailer::TestCase
  test "check_in comes from Mahad and asks about Hackatime" do
    user = User.create!(timezone: "UTC", username: "checkinuser")
    recipient = "check-in-#{SecureRandom.hex(4)}@example.com"

    mail = OnboardingMailer.check_in(user, recipient_email: recipient)

    assert_equal [ recipient ], mail.to
    assert_equal [ "mahad@hackclub.com" ], mail.from
    assert_equal "How are you finding Hackatime?", mail.subject
    assert_includes mail.html_part.body.decoded, "<strong>Mahad Kalam</strong>"
    assert_includes mail.text_part.body.decoded, "reply to this email"
    assert_includes mail.text_part.body.decoded, "Hackatime Lead @ Hack Club"
    assert_not_includes mail.html_part.body.decoded, "15 Falls Road"
  end
end
