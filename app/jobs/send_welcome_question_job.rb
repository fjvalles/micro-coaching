class SendWelcomeQuestionJob < ApplicationJob
  queue_as :default

  QUESTION = "¿Cuál es el patrón automático que más quieres interrumpir en estos 14 días?".freeze

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return if initial_pattern_already_answered?(participant)
    return if welcome_question_already_sent?(participant)

    Outbound::Dispatcher.new(participant: participant, moment: :welcome, day_number: 0).send_text(body: QUESTION)
  end

  private

  def initial_pattern_already_answered?(participant)
    participant.initial_pattern.present? ||
      participant.conversations.kept.where(moment: :welcome, role: :user).exists?
  end

  def welcome_question_already_sent?(participant)
    participant.conversations.kept
               .where(moment: :welcome, role: :assistant, day_number: 0, body: QUESTION)
               .where.not(sent_at: nil)
               .exists?
  end
end
