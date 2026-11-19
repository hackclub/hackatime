require "test_helper"

class ProjectDetectionMailerTest < ActionMailer::TestCase
  test "home_folder_project explains the stray repository without escaping the plain text" do
    user = create(:user)

    mail = ProjectDetectionMailer.home_folder_project(user, recipient_email: "user@example.com", project: "Tom & Jerry", folder: "C:/Users/Tom & Jerry")

    assert_equal [ "user@example.com" ], mail.to
    assert_equal "Hackatime is logging your coding time to \"Tom & Jerry\"", mail.subject
    text = mail.text_part.body.decoded
    assert_includes text, "a project called Tom & Jerry."
    assert_includes text, "There is a .git folder in C:/Users/Tom & Jerry."
    assert_includes text, "http://example.com/docs/configuration/projects"
    assert_includes text, "ask in #hackatime-help on Slack: https://hackclub.slack.com/archives/C07MQ845X1F"
    assert_includes mail.html_part.body.decoded, "<code>C:/Users/Tom &amp; Jerry</code>"
  end
end
