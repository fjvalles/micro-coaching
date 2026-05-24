class GenerateAndSendManifestoJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return if participant.closing_manifesto.present?

    result = Openai::ManifestoGenerator.new(participant: participant).call
    participant.update!(closing_manifesto: result.body)

    response = Whatsapp::Client.new.send_text(to: participant.phone_e164, body: result.body)
    Conversation.create!(
      participant: participant,
      day_number: 14,
      moment: :manifesto,
      role: :assistant,
      body: result.body,
      whatsapp_message_id: response.wamid,
      sent_at: response.success? ? Time.current : nil,
      error_message: response.success? ? nil : response.error,
      prompt_used: result.prompt_used,
      tokens_input: result.tokens_input,
      tokens_output: result.tokens_output,
      model_used: result.model
    )
  end
end
