class PauseInactiveParticipantsJob < ApplicationJob
  queue_as :default

  # Pauses active participants who have not sent any inbound message in the last
  # `inactivity_pause_days` days. A new inbound reactivates them
  # (ProcessIncomingMessageJob#reactivate_if_paused). Idempotent: already-paused
  # participants are out of the `.active` scope.
  def perform
    days = Setting.fetch("inactivity_pause_days").to_i
    return unless days.positive?

    cutoff = days.days.ago

    Participant.kept.active.find_each do |participant|
      # Grace window: don't pause someone who only just enrolled.
      next if participant.enrolled_at.present? && participant.enrolled_at > cutoff

      last_inbound = participant.last_inbound_at
      next if last_inbound.present? && last_inbound > cutoff

      PaperTrail.request(whodunnit: "system:PauseInactive", controller_info: { source: "system" }) do
        participant.update!(status: :paused)
      end
    end
  end
end
