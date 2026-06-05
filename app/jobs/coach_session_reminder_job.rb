class CoachSessionReminderJob < ApplicationJob
  queue_as :default

  # Sends a WhatsApp reminder for each confirmed coach session starting within the
  # lead window. Idempotent: stamps reminder_sent_at and the due_for_reminder scope
  # excludes already-reminded sessions, so re-running the same hour won't double-send.
  # Honors the response-mode switch via Outbound::Dispatcher (auto sends; otherwise
  # queues a PendingResponse for admin review).
  def perform
    lead_hours = Setting.fetch("coach_session_reminder_lead_hours").to_i
    return unless lead_hours.positive?

    CoachSession.due_for_reminder(lead_hours.hours).find_each do |session|
      remind(session)
    end
  end

  private

  def remind(session)
    participant = session.participant
    return unless participant&.kept?

    body = reminder_text(session)
    Outbound::Dispatcher.new(participant: participant, moment: :free_assistant).send_text(body: body)

    PaperTrail.request(whodunnit: "system:CoachSessionReminder", controller_info: { source: "system" }) do
      session.update!(reminder_sent_at: Time.current)
    end
  end

  def reminder_text(session)
    local = session.scheduled_at.in_time_zone(session.participant.timezone)
    when_str = local.strftime("%d/%m a las %H:%M")
    coach = session.coach&.name.presence || Setting.fetch("coach_name").to_s.presence || "tu coach"
    link  = session.meeting_url.present? ? "\n\nEnlace: #{session.meeting_url}" : ""
    "Recordatorio: tienes una sesión 1-1 con #{coach} el #{when_str} (#{session.participant.timezone}).#{link}"
  end
end
