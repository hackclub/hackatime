class ApplicationMailer < ActionMailer::Base
  include Mailkick::UrlHelper

  default from: "Hackatime <#{ENV.fetch("SMTP_FROM_EMAIL", "hackatime@hackclub.com")}>"
  layout "mailer"
end
