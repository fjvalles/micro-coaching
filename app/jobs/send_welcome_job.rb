class SendWelcomeJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)

    welcome_message = Whatsapp::TemplateSender.new(
      participant: participant,
      template_name: "bienvenida_piloto",
      moment: :welcome,
      day_number: 0,
      variables: [ participant.name ]
    ).call

    return unless welcome_message.sent_at?

    delay = Setting.fetch("welcome_question_delay_minutes").to_i.minutes
    SendWelcomeQuestionJob.set(wait: delay).perform_later(participant.id)
  end
end
