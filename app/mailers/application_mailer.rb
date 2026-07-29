class ApplicationMailer < ActionMailer::Base
  default from: -> { "SCATS <#{ENV.fetch("GMAIL_USERNAME", "noreply@scats.local")}>" }
  layout "mailer"
end
