class CheckinForParticipantJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content

    already = participant.conversations.kept
                .where(moment: :checkin_question, day_number: participant.current_day)
                .where("created_at >= ?", participant.local_time.beginning_of_day)
                .exists?
    return if already

    questions = day_content.checkin_questions.to_s
    body = "Check-in del día #{day_content.day_number} — #{day_content.title}\n\n#{questions}"

    if participant.in_24h_window?
      response = Whatsapp::Client.new.send_text(to: participant.phone_e164, body: body)
      Conversation.create!(
        participant: participant, day_number: participant.current_day,
        moment: :checkin_question, role: :assistant, body: body,
        whatsapp_message_id: response.wamid,
        sent_at: response.success? ? Time.current : nil,
        error_message: response.success? ? nil : response.error
      )
    else
      Whatsapp::TemplateSender.new(
        participant: participant,
        template_name: "checkin_dia_%02d" % day_content.day_number,
        moment: :checkin_question, day_number: day_content.day_number,
        variables: [participant.name, *questions.split("\n").first(3)]
      ).call
    end

    participant.update!(pending_checkin_at: Time.current)
  end
end
