class ProjectDetectionMailerPreview < ActionMailer::Preview
  def home_folder_project
    user = User.first || User.new(username: "preview_user", timezone: "UTC")

    ProjectDetectionMailer.home_folder_project(user, recipient_email: "user@example.com", project: "kevin", folder: "C:/Users/kevin")
  end
end
