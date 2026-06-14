class SendNivel2OfferJob < ApplicationJob
  queue_as :default

  # Day-14 upsell: after the closing manifesto, invite the participant to design a
  # paid personalized Nivel 2. The AI generator writes the day1→day14 contrast
  # ("unlock your investment"); this job appends the deterministic terms (founder
  # window + guarantee, never invented by the model) and stamps nivel2_offer_sent_at
  # to open the founder window.
  #
  # Gated by the nivel2_offer_enabled kill-switch. Idempotent: one offer per
  # participant (no prior :nivel2_offer conversation).
  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return unless Setting.fetch("nivel2_offer_enabled")
    return unless participant.completed?
    return if offer_already_sent?(participant)

    mode = ResponseMode.for(participant)
    body, ai = generate(participant, mode)
    return if body.blank?

    result = Outbound::Dispatcher.new(
      participant: participant, moment: :nivel2_offer, day_number: participant.current_day, mode: mode
    ).send_text(body: body + cta_text, ai: ai)

    return unless result.delivered? || result.queued?

    PaperTrail.request(whodunnit: "ai:SendNivel2Offer", controller_info: { source: "ai" }) do
      participant.update!(nivel2_offer_sent_at: Time.current)
    end
  end

  private

  def offer_already_sent?(participant)
    participant.conversations.kept.where(moment: :nivel2_offer).exists? ||
      PendingResponse.kept.where(participant: participant, moment: "nivel2_offer")
                     .where(status: %w[pending approved sent]).exists?
  end

  # Manual mode means no AI body is expected upstream; queue an empty draft for the
  # admin to compose (mirrors GenerateAndSendManifestoJob).
  def generate(participant, mode)
    return [ " ", {} ] if mode == "manual"

    result = Openai::Nivel2OfferGenerator.new(participant: participant).call
    ai_meta = {
      prompt_used: result.prompt_used,
      tokens_input: result.tokens_input,
      tokens_output: result.tokens_output,
      model: result.model
    }
    [ result.body, ai_meta ]
  end

  def cta_text
    hours = Setting.fetch("nivel2_offer_window_hours").to_i
    "\n\n" + format(Setting.fetch("nivel2_offer_cta_text"), hours: hours)
  end
end
