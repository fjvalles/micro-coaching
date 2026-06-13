class SendIaretoJob < ApplicationJob
  include IdempotentOutbound
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content&.iareto_text.present?

    return if already_handled?(participant: participant, moment: :iareto, day_number: participant.current_day)

    dispatcher = Outbound::Dispatcher.new(participant: participant, moment: :iareto, day_number: day_content.day_number)
    if participant.in_24h_window?
      dispatcher.send_text(body: day_content.iareto_text)
    else
      dispatcher.send_template(
        template_name: Whatsapp::DailyTemplateName.call(prefix: "iareto", day_number: day_content.day_number),
        variables: [ participant.name, day_content.iareto_text ],
        body_preview: day_content.iareto_text
      )
    end
  end
end
