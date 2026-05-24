class SendWelcomeQuestionJob < ApplicationJob
  queue_as :default

  QUESTION = "¿Cuál es el patrón automático que más quieres interrumpir en estos 14 días?".freeze

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    client = Whatsapp::Client.new
    response = client.send_text(to: participant.phone_e164, body: QUESTION)

    Conversation.create!(
      participant: participant,
      day_number: 0,
      moment: :welcome,
      role: :assistant,
      body: QUESTION,
      whatsapp_message_id: response.wamid,
      sent_at: response.success? ? Time.current : nil,
      error_message: response.success? ? nil : response.error
    )
  end
end
