class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_FROM_EMAIL", "noreply@timedump.hackclub.com")
  layout "mailer"
end
