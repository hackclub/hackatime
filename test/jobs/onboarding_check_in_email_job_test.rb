require "test_helper"

class OnboardingCheckInEmailJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "sends check in email to the user's first email address" do
    user = User.create!(timezone: "UTC")
    first_email = user.email_addresses.create!(email: "first-#{SecureRandom.hex(4)}@example.com", source: :signing_in)
    user.email_addresses.create!(email: "second-#{SecureRandom.hex(4)}@example.com", source: :signing_in)

    assert_emails 1 do
      OnboardingCheckInEmailJob.perform_now(user.id)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ first_email.email ], mail.to
    assert_equal "How are you finding Hackatime?", mail.subject
  end

  test "does not send check in email without an email address" do
    user = User.create!(timezone: "UTC")

    assert_no_emails do
      OnboardingCheckInEmailJob.perform_now(user.id)
    end
  end
end
