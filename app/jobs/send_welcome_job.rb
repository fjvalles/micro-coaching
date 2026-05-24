class SendWelcomeJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)

    result = Outbound::Dispatcher.new(
      participant: participant, moment: :welcome, day_number: 0
    ).send_template(
      template_name: "bienvenida_piloto",
      variables: [ participant.name ],
      body_preview: "Bienvenida #{participant.name}"
    )

    return unless result.delivered? && result.conversation&.sent_at?

    delay = Setting.fetch("welcome_question_delay_minutes").to_i.minutes
    SendWelcomeQuestionJob.set(wait: delay).perform_later(participant.id)
  end
end
