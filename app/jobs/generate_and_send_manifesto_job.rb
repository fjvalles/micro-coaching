class GenerateAndSendManifestoJob < ApplicationJob
  queue_as :default

  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return if participant.closing_manifesto.present?

    mode = ResponseMode.for(participant)
    body, ai = generate(participant, mode)

    Outbound::Dispatcher.new(
      participant: participant, moment: :manifesto, day_number: 14, mode: mode
    ).send_text(body: body, ai: ai)
  end

  private

  def generate(participant, mode)
    return [ "", {} ] if mode == "manual"

    result = Openai::ManifestoGenerator.new(participant: participant).call
    PaperTrail.request(whodunnit: "ai:ManifestoGenerator", controller_info: { source: "ai" }) do
      participant.update!(closing_manifesto: result.body)
    end
    ai_meta = {
      prompt_used: result.prompt_used,
      tokens_input: result.tokens_input,
      tokens_output: result.tokens_output,
      model: result.model
    }
    [ result.body, ai_meta ]
  end
end
