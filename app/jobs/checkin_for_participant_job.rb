class CheckinForParticipantJob < ApplicationJob
  include IdempotentOutbound
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    day_content = participant.day_content
    return unless day_content

    return if already_handled?(participant: participant, moment: :checkin_question, day_number: participant.current_day)

    questions = day_content.checkin_questions.to_s
    body = "Check-in del día #{day_content.day_number} — #{day_content.title}\n\n#{questions}"

    dispatcher = Outbound::Dispatcher.new(
      participant: participant, moment: :checkin_question, day_number: day_content.day_number
    )
    result = if participant.in_24h_window?
               dispatcher.send_text(body: body)
    else
               dispatcher.send_template(
                 template_name: "checkin_dia_%02d" % day_content.day_number,
                 variables: [ participant.name, *questions.split("\n").first(3) ],
                 body_preview: body
               )
    end

    if result.delivered?
      PaperTrail.request(whodunnit: "ai:CheckinJob", controller_info: { source: "ai" }) do
        participant.update!(pending_checkin_at: Time.current)
      end
    end
  end
end
