class SendIaretoJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content&.iareto_text.present?

    already = participant.conversations.kept
                .where(moment: :iareto, day_number: participant.current_day)
                .where("created_at >= ?", participant.local_time.beginning_of_day)
                .exists?
    return if already

    if participant.in_24h_window?
      response = Whatsapp::Client.new.send_text(to: participant.phone_e164, body: day_content.iareto_text)
      Conversation.create!(
        participant: participant,
        day_number: participant.current_day,
        moment: :iareto,
        role: :assistant,
        body: day_content.iareto_text,
        whatsapp_message_id: response.wamid,
        sent_at: response.success? ? Time.current : nil,
        error_message: response.success? ? nil : response.error
      )
    else
      Whatsapp::TemplateSender.new(
        participant: participant,
        template_name: "iareto_dia_%02d" % day_content.day_number,
        moment: :iareto,
        day_number: day_content.day_number,
        variables: [participant.name, day_content.iareto_text]
      ).call
    end
  end
end
