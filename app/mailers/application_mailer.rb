class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Impulso <noreply@impulso.comtraining.cl>")
  layout "mailer"
end
