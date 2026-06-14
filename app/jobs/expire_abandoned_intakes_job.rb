class ExpireAbandonedIntakesJob < ApplicationJob
  queue_as :default

  # Frees participants who entered the personalized-program intake but stalled
  # without finishing — they'd otherwise sit in :intake forever, never re-prompted
  # and never re-enrollable. A participant past `intake_abandonment_days` of
  # inactivity is reverted out of intake: back to :completed if they'd already
  # finished a prior cycle (the day-14 upsell case), otherwise to :pending.
  #
  # Excludes :awaiting_review participants — their program is generated and waiting
  # on a human, not abandoned by the participant. Idempotent: a reverted participant
  # leaves the :intake scope.
  def perform
    days = Setting.fetch("intake_abandonment_days").to_i
    return unless days.positive?

    cutoff = days.days.ago

    Participant.kept.where(status: :intake).find_each do |participant|
      next if participant.intake_awaiting_review?
      next if participant.updated_at > cutoff

      target = participant.completed_at.present? ? :completed : :pending
      PaperTrail.request(whodunnit: "system:ExpireAbandonedIntakes", controller_info: { source: "system" }) do
        participant.update!(status: target, intake_state: {})
      end
      Rails.logger.info("ExpireAbandonedIntakesJob: reverted participant #{participant.id} to #{target}")
    end
  end
end
