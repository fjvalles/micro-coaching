class PromptTuningMailer < ApplicationMailer
  def proposal(prompt_tuning_run_id)
    @run = PromptTuningRun.find(prompt_tuning_run_id)
    recipients = AdminUser.where(superadmin: true).pluck(:email).presence || [ AdminUser.first&.email ].compact
    return if recipients.blank?

    mail(to: recipients, subject: "Propuesta de auto-tuning de prompt: score #{@run.score}/100")
  end
end
