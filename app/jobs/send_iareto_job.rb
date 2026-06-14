class SendIaretoJob < ApplicationJob
  include IdempotentOutbound
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content&.iareto_text.present?

    return if already_handled?(participant: participant, moment: :iareto, day_number: participant.current_day)

    dispatcher = Outbound::Dispatcher.new(participant: participant, moment: :iareto, day_number: day_content.day_number)
    body = template_body(day_content.iareto_text, participant)
    if participant.in_24h_window?
      dispatcher.send_text(body: body)
    else
      dispatcher.send_template(
        template_name: Whatsapp::DailyTemplateName.call(prefix: "iareto", day_number: day_content.day_number),
        variables: [ participant.name, body ],
        body_preview: body
      )
    end
  end

  private

  def template_body(body, participant)
    Whatsapp::TemplateBodySanitizer.call(body, participant_name: participant.name)
  end
end
