class SendParticipantReminderJob < ApplicationJob
  queue_as :default

  def perform(reminder_id)
    reminder = ParticipantReminder.find_by(id: reminder_id)
    return unless reminder&.pending?
    return if reminder.scheduled_at > Time.current + 1.minute

    reminder.with_lock do
      reminder.reload
      return unless reminder.pending?

      participant = Participant.kept.find_by(id: reminder.participant_id)
      return mark_failed(reminder, "participant_not_available") unless participant
      return cancel(reminder, "participant_paused") unless participant.active?

      result = deliver(reminder, participant)
      if result.sent?
        reminder.update!(status: :sent, sent_at: Time.current, sent_conversation: result.conversation)
      else
        mark_failed(reminder, result.skipped_reason || result.error || "send_failed")
      end
    end
  end

  private

  def deliver(reminder, participant)
    if participant.in_24h_window?
      Outbound::AdminMessage.new(participant: participant, kind: "text", body: reminder.body).call
    else
      template = Setting.fetch("participant_reminder_template_name").to_s
      return Outbound::AdminMessage::Result.new(sent: false, skipped_reason: :outside_24h_window) if template.blank?

      Outbound::AdminMessage.new(
        participant: participant,
        kind: "template",
        template_name: template,
        variables: [ participant.name, reminder.body ]
      ).call
    end
  end

  def cancel(reminder, reason)
    reminder.update!(status: :canceled, canceled_at: Time.current, failure_reason: reason)
  end

  def mark_failed(reminder, reason)
    reminder.update!(status: :failed, failure_reason: reason.to_s)
  end
end
