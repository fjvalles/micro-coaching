class ProcessIncomingMessageJob < ApplicationJob
  queue_as :default

  AUDIO_TYPES = %w[audio voice].freeze

  def perform(payload)
    parsed = Whatsapp::InboundParser.parse(payload)

    parsed[:statuses].each { |s| update_status(s) }
    parsed[:messages].each { |m| process_message(m) }
  end

  private

  def update_status(status)
    convo = Conversation.find_by(whatsapp_message_id: status.wamid)
    return unless convo

    case status.status
    when "delivered" then convo.update(delivered_at: Time.current) unless convo.delivered_at
    when "read"      then convo.update(read_at: Time.current) unless convo.read_at
    when "failed"    then convo.update(error_message: "Meta reported failed status")
    end
  end

  def process_message(message)
    participant = Participant.kept.find_by(phone_e164: "+#{message.from}") ||
                  Participant.kept.find_by(phone_e164: message.from)
    return unless participant

    if AUDIO_TYPES.include?(message.type)
      process_audio_message(participant, message)
      return
    end

    if message.type != "text" && message.text.blank?
      reject_non_text(participant)
      return
    end

    inbound = Conversation.create!(
      participant: participant,
      day_number: participant.current_day,
      moment: :free_user,
      role: :user,
      body: message.text.to_s,
      whatsapp_message_id: message.wamid,
      sent_at: Time.zone.at(message.timestamp.to_i)
    )

    dispatch(participant, inbound, message.text.to_s)
  end

  def process_audio_message(participant, message)
    unless Setting.fetch("audio_processing_enabled")
      reject_non_text(participant)
      return
    end

    inbound = Conversation.create!(
      participant: participant,
      day_number: participant.current_day,
      moment: :free_user,
      role: :user,
      body: "",
      media_id: message.media_id,
      whatsapp_message_id: message.wamid,
      sent_at: Time.zone.at(message.timestamp.to_i)
    )

    result = Participants::AudioProcessor.new(conversation: inbound, media_id: message.media_id).call

    if result.error || result.transcription.blank?
      reject_non_text(participant)
      return
    end

    if result.too_long
      ack(participant, "Recibí tu audio pero es muy largo. ¿Me lo puedes resumir en uno más corto o por escrito?")
      return
    end

    dispatch(participant, inbound, result.transcription, voice_analysis: result.voice_analysis)
  end

  def dispatch(participant, inbound, text, voice_analysis: nil)
    classification = Participants::MessageClassifier.new(participant: participant).classify

    case classification.type
    when :initial_pattern_answer
      participant.update!(initial_pattern: text)
      inbound.update!(moment: :welcome)
      ack(participant, "Recibido. Mañana empieza tu primer día.")
    when :checkin_response
      inbound.update!(moment: :checkin_response)
      handle_checkin(participant, text, voice_analysis: voice_analysis)
    else
      handle_free(participant, text, voice_analysis: voice_analysis)
    end
  end

  def handle_checkin(participant, text, voice_analysis: nil)
    day_content = participant.day_content
    enriched = enrich_with_voice(text, voice_analysis)

    result = Openai::CheckinSummarizer.new(
      participant: participant, day_content: day_content, raw_text: enriched
    ).call

    DailyReport.create!(
      participant: participant,
      day_number: participant.current_day,
      raw_text: enriched,
      ai_summary: result.summary,
      ai_key_pattern: result.key_pattern,
      reported_at: Time.current
    )

    ack(participant, "Gracias. Mañana retomamos.", moment: :free_assistant,
        prompt_used: result.prompt_used, tokens_input: result.tokens_input,
        tokens_output: result.tokens_output, model_used: result.model)
  end

  def handle_free(participant, text, voice_analysis: nil)
    enriched = enrich_with_voice(text, voice_analysis)

    result = Openai::FreeResponseGenerator.new(
      participant: participant, user_message: enriched
    ).call

    ack(participant, result.body, moment: :free_assistant,
        prompt_used: result.prompt_used, tokens_input: result.tokens_input,
        tokens_output: result.tokens_output, model_used: result.model)
  end

  # Appends a brief paralinguistic note so the LLM can attend to tone/emotion
  # without polluting the literal transcription stored on the Conversation.
  def enrich_with_voice(text, voice_analysis)
    return text if voice_analysis.blank?

    fields = voice_analysis.slice("tone", "primary_emotion", "energy_level", "pace", "vocal_qualities", "key_observations")
    return text if fields.values.all?(&:blank?)

    summary = fields.compact.map { |k, v| "#{k}: #{Array(v).join(', ')}" }.join(" | ")
    "#{text}\n\n[Nota paralingüística inferida del audio: #{summary}]"
  end

  def ack(participant, body, moment: :free_assistant, **extra)
    response = Whatsapp::Client.new.send_text(to: participant.phone_e164, body: body)
    Conversation.create!(
      participant: participant,
      day_number: participant.current_day,
      moment: moment,
      role: :assistant,
      body: body,
      whatsapp_message_id: response.wamid,
      sent_at: response.success? ? Time.current : nil,
      error_message: response.success? ? nil : response.error,
      **extra
    )
  end

  def reject_non_text(participant)
    Whatsapp::Client.new.send_text(
      to: participant.phone_e164,
      body: Setting.fetch("voice_message_reply_text").to_s
    )
  end
end
