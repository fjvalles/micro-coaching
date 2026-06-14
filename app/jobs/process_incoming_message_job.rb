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
    normalized = message.from.start_with?("+") ? message.from : "+#{message.from}"
    participant = Participant.kept.find_by(phone_e164: normalized)

    unless participant
      log_unknown_inbound(message)
      return
    end

    reactivate_if_paused(participant)
    maybe_send_program_overview(participant)

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
    when :program_intake
      handle_program_intake(participant, inbound, text)
    when :initial_pattern_answer
      intent = classify_inbound_intent(
        participant: participant, inbound: inbound, text: text,
        checkin_pending: false
      )
      intent = initial_pattern_intent(classification) unless intent.restricted_information_request?
      record_inbound_intent!(inbound, intent)
      return handle_restricted_information(participant) if intent.restricted_information_request?

      PaperTrail.request(whodunnit: "ai:MessageClassifier", controller_info: { source: "ai" }) do
        participant.update!(initial_pattern: text)
      end
      inbound.update!(moment: :welcome)
      ack(participant, "Recibido. Mañana empieza tu primer día.")
    when :checkin_response
      intent = classify_inbound_intent(
        participant: participant, inbound: inbound, text: text,
        checkin_pending: true
      )
      record_inbound_intent!(inbound, intent)

      unless intent.checkin_answer?(Setting.fetch("inbound_intent_min_confidence"))
        taggable = route_by_intent(
          participant: participant, inbound: inbound, text: text, intent: intent,
          voice_analysis: voice_analysis,
          operational_context: Setting.fetch("checkin_pending_followup_text").to_s
        )
        enqueue_skill_tagging(inbound) if taggable
        return
      end

      inbound.update!(moment: :checkin_response)
      handle_checkin(participant, text, voice_analysis: voice_analysis)
      enqueue_skill_tagging(inbound)
      RefreshParticipantSummaryJob.perform_later(participant.id) if Setting.fetch("participant_summary_enabled")
    else
      intent = classify_inbound_intent(
        participant: participant, inbound: inbound, text: text,
        checkin_pending: false
      )
      record_inbound_intent!(inbound, intent)

      taggable = route_by_intent(
        participant: participant, inbound: inbound, text: text, intent: intent,
        voice_analysis: voice_analysis
      )
      enqueue_skill_tagging(inbound) if taggable
    end
  end

  # Records one intake answer, then either asks the next question or kicks off
  # program generation when the questionnaire is complete. The inbound is reclassified
  # off free_user so it doesn't count toward the free-message cap.
  def handle_program_intake(participant, inbound, text)
    inbound.update!(moment: :program_intake)

    # First reply after the opener template: this message only opens the 24h window
    # (the participant hasn't seen any question yet). Don't record it as an answer —
    # send the first question now that free text is allowed.
    if participant.intake_state["awaiting_open"]
      PaperTrail.request(whodunnit: "ai:ProcessIncomingMessage", controller_info: { source: "ai" }) do
        participant.update!(intake_state: participant.intake_state.merge("awaiting_open" => false))
      end
      first_question = Participants::IntakeQuestions.at(participant.intake_step)
      ack(participant, first_question[:text], moment: :program_intake) if first_question
      return
    end

    result = Participants::IntakeHandler.new(participant: participant, answer_text: text).call

    if result.complete?
      ack(participant, Setting.fetch("program_intake_building_text"), moment: :program_intake)
      ProgramGenerationJob.perform_later(participant.id)
    else
      ack(participant, result.next_question, moment: :program_intake)
    end
  end

  # Cold-enroll path for the "what to expect" overview: the inbound just opened the
  # 24h window, so (re)enqueue the overview. Cheap pre-filter to program start; the
  # job re-validates window, recency, and idempotency, so old/re-engaged participants
  # never get back-filled.
  def maybe_send_program_overview(participant)
    return unless participant.active? && participant.program_id.present? && participant.current_day.to_i <= 1

    SendProgramOverviewJob.perform_later(participant.id)
  end

  # Async detection of the participant's human skills in this inbound. Gated +
  # idempotent inside the job; the reply is already on its way, so this adds no
  # latency. Initial-pattern answers are skipped (not coachable conversation yet).
  def enqueue_skill_tagging(conversation)
    return unless Setting.fetch("skill_tagging_enabled")

    TagConversationSkillsJob.perform_later(conversation.id)
  end

  def handle_checkin(participant, text, voice_analysis: nil)
    enriched = enrich_with_voice(text, voice_analysis)

    if ResponseMode.manual?(participant)
      Outbound::Dispatcher.new(participant: participant, moment: :free_assistant).send_text(body: "")
      return
    end

    day_content = participant.day_content
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

  def handle_free(participant, text, voice_analysis: nil, operational_context: nil)
    if ResponseMode.manual?(participant)
      Outbound::Dispatcher.new(participant: participant, moment: :free_assistant).send_text(body: "")
      return
    end

    return if free_cap_reached?(participant)

    enriched = enrich_with_voice(text, voice_analysis)
    result = Openai::FreeResponseGenerator.new(
      participant: participant, user_message: enriched, operational_context: operational_context
    ).call

    ack(participant, result.body, moment: :free_assistant,
        prompt_used: result.prompt_used, tokens_input: result.tokens_input,
        tokens_output: result.tokens_output, model_used: result.model)
  end

  def route_by_intent(participant:, inbound:, text:, intent:, voice_analysis: nil, operational_context: nil)
    if intent.stop_or_pause?
      handle_stop_or_pause(participant)
      return false
    end

    if intent.risk_or_sensitive?
      queue_human_review(participant, inbound, intent, Setting.fetch("sensitive_request_review_reply_text").to_s)
      return false
    end

    if intent.support_request?
      queue_human_review(participant, inbound, intent, Setting.fetch("support_request_review_reply_text").to_s)
      return false
    end

    if intent.restricted_information_request?
      handle_restricted_information(participant)
      return false
    end

    handle_free(participant, text, voice_analysis: voice_analysis, operational_context: operational_context)
    true
  end

  def initial_pattern_intent(classification)
    Participants::InboundIntentClassifier::Result.new(
      intent: "initial_pattern_answer",
      confidence: 1.0,
      reason: classification.reason,
      model: "state"
    )
  end

  def handle_restricted_information(participant)
    ack(participant, Setting.fetch("restricted_information_reply_text").to_s)
  end

  def handle_stop_or_pause(participant)
    PaperTrail.request(whodunnit: "system:InboundIntentClassifier", controller_info: { source: "system" }) do
      participant.update!(status: :paused) unless participant.paused?
    end

    ack(participant, Setting.fetch("pause_request_reply_text").to_s)
  end

  def queue_human_review(participant, inbound, intent, body)
    result = Outbound::Dispatcher.new(participant: participant, moment: :free_assistant, mode: "approve").send_text(
      body: body,
      ai: {
        prompt_used: intent.prompt_used,
        tokens_input: intent.tokens_input,
        tokens_output: intent.tokens_output,
        model: intent.model
      }
    )
    result.pending_response&.update!(conversation: inbound)
  end

  def classify_inbound_intent(participant:, inbound:, text:, checkin_pending:)
    Participants::InboundIntentClassifier.new(
      participant: participant,
      text: text,
      checkin_pending: checkin_pending,
      conversation: inbound
    ).call
  end

  def record_inbound_intent!(inbound, intent)
    inbound.update!(
      inbound_intent: intent.intent,
      inbound_intent_confidence: intent.confidence,
      inbound_intent_reason: intent.reason
    )
  end

  def enrich_with_voice(text, voice_analysis)
    return text if voice_analysis.blank?

    fields = voice_analysis.slice("tone", "primary_emotion", "energy_level", "pace", "vocal_qualities", "key_observations")
    return text if fields.values.all?(&:blank?)

    summary = fields.compact.map { |k, v| "#{k}: #{Array(v).join(', ')}" }.join(" | ")
    "#{text}\n\n[Nota paralingüística inferida del audio: #{summary}]"
  end

  def ack(participant, body, moment: :free_assistant, **extra)
    Outbound::Dispatcher.new(participant: participant, moment: moment).send_text(body: body, ai: extra)
  end

  # Daily free-chat cap. Returns true (and stops the AI reply) once the participant
  # exceeds max_free_messages_per_day. The over-limit notice is sent exactly once.
  def free_cap_reached?(participant)
    cap = Setting.fetch("max_free_messages_per_day").to_i
    return false unless cap.positive?

    used = participant.free_inbounds_today
    return false if used <= cap

    ack(participant, Setting.fetch("free_messages_cap_reply_text").to_s) if used == cap + 1
    true
  end

  # Any inbound message reactivates a participant that PauseInactiveParticipantsJob paused.
  def reactivate_if_paused(participant)
    return unless participant.paused?

    PaperTrail.request(whodunnit: "system:InboundReactivation", controller_info: { source: "system" }) do
      participant.update!(status: :active)
    end
  end

  def reject_non_text(participant)
    Outbound::Dispatcher.new(participant: participant, moment: :free_assistant).send_text(
      body: Setting.fetch("voice_message_reply_text").to_s
    )
  end

  def log_unknown_inbound(message)
    phone = message.from.start_with?("+") ? message.from : "+#{message.from}"
    preview = message.text.to_s.truncate(200).presence

    Rails.logger.warn("[UnknownInbound] phone=#{phone} type=#{message.type} wamid=#{message.wamid}")

    UnknownInbound.create!(
      phone: phone,
      wamid: message.wamid,
      message_type: message.type,
      body_preview: preview,
      received_at: Time.zone.at(message.timestamp.to_i)
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # duplicate webhook delivery — already logged
  end
end
