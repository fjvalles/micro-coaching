class CheckinForParticipantJob < ApplicationJob
  include IdempotentOutbound
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content

    return if already_handled?(participant: participant, moment: :checkin_question, day_number: participant.current_day)

    questions = template_body(day_content.checkin_questions, participant)
    body = "Check-in del día #{day_content.day_number} — #{day_content.title}\n\n#{questions}"

    dispatcher = Outbound::Dispatcher.new(
      participant: participant, moment: :checkin_question, day_number: day_content.day_number
    )
    result = if participant.in_24h_window?
               dispatcher.send_text(body: body)
    else
               dispatcher.send_template(
                 template_name: Whatsapp::DailyTemplateName.call(prefix: "checkin", day_number: day_content.day_number),
                 variables: [ participant.name, questions.split("\n").reject(&:blank?).first(3).join("\n\n") ],
                 body_preview: body
               )
    end

    if result.delivered?
      PaperTrail.request(whodunnit: "ai:CheckinJob", controller_info: { source: "ai" }) do
        participant.update!(pending_checkin_at: Time.current)
      end
    end
  end

  private

  def template_body(body, participant)
    Whatsapp::TemplateBodySanitizer.call(body, participant_name: participant.name)
  end
end
