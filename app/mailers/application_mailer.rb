class ApplicationMailer < ActionMailer::Base
  include Mailkick::UrlHelper

  default from: "Hackatime <#{ENV.fetch("SMTP_FROM_EMAIL", "noreply@timedump.hackclub.com")}>"
  layout "mailer"
end
