class ProjectDetectionMailer < ApplicationMailer
  def home_folder_project(user, recipient_email:, project:, folder:)
    @user = user
    @project = project
    @folder = folder
    @docs_url = "#{root_url}docs/configuration/projects"

    mail(to: recipient_email, subject: "Hackatime is logging your coding time to \"#{project}\"")
  end
end
