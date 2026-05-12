class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM_EMAIL", "no-reply@qpaper.app")
  layout "mailer"
end
