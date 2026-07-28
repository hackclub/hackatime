require "test_helper"

class LoopsMailerTest < ActionMailer::TestCase
  test "sign_in_email renders standard erb html and text versions" do
    token = "test-sign-in-token"
    recipient = "loops-login-#{SecureRandom.hex(4)}@example.com"

    mail = LoopsMailer.sign_in_email(recipient, token)

    assert_equal [ recipient ], mail.to
    assert_equal "Your Hackatime sign-in link", mail.subject
    assert_includes mail.html_part.body.decoded, "Sign in to Hackatime"
    assert_includes mail.text_part.body.decoded, "/auth/token/#{token}"
  end
end
