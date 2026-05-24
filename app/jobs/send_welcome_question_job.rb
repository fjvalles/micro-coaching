class SendWelcomeQuestionJob < ApplicationJob
  queue_as :default

  QUESTION = "¿Cuál es el patrón automático que más quieres interrumpir en estos 14 días?".freeze

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    Outbound::Dispatcher.new(participant: participant, moment: :welcome, day_number: 0).send_text(body: QUESTION)
  end
end
