class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAIL_FROM', 'noreply@careconnect.com')
  layout "mailer"
end
