class SendProgramOverviewJob < ApplicationJob
  queue_as :default

  # Sends the program "what to expect" overview to a participant who just started a
  # program (fresh enroll or approved personalized program). WhatsApp only allows
  # free-form text inside the 24h customer-service window, so this self-gates on it:
  # if the window is closed (cold enroll, no prior inbound) it skips, and
  # ProcessIncomingMessageJob re-enqueues it once the participant's first reply opens
  # the window.
  #
  # Idempotent and scoped to program start (current_day <= 1, recently started) so it
  # never back-fills long-running or re-engaged participants.
  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return unless eligible?(participant)
    return unless participant.in_24h_window?
    return if already_handled?(participant)

    body = Programs::OverviewMessage.new(participant).call
    return if body.blank?

    Outbound::Dispatcher.new(
      participant: participant, moment: :program_overview, day_number: participant.current_day
    ).send_text(body: body)
  end

  private

  def eligible?(participant)
    participant.active? &&
      participant.program_id.present? &&
      participant.current_day.to_i <= 1 &&
      participant.started_at.present? &&
      participant.started_at > 3.days.ago
  end

  def already_handled?(participant)
    participant.conversations.kept
               .where(moment: :program_overview)
               .where.not(sent_at: nil)
               .exists? ||
      PendingResponse.kept
                     .where(participant: participant, moment: "program_overview")
                     .where(status: %w[pending approved sent])
                     .exists?
  end
end
