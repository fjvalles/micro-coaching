module Participants
  class InboundIntentClassifier
    INTENTS = %w[
      checkin_answer
      program_question
      support_request
      restricted_information_request
      reminder_request
      task_acknowledgement
      off_topic
      risk_or_sensitive
      stop_or_pause
      unclear
    ].freeze

    Result = Struct.new(
      :intent, :confidence, :reason, :prompt_used, :tokens_input, :tokens_output, :model,
      keyword_init: true
    ) do
      def checkin_answer?(threshold)
        intent == "checkin_answer" && confidence.to_f >= threshold.to_f
      end

      def support_request? = intent == "support_request"
      def restricted_information_request? = intent == "restricted_information_request"
      def reminder_request? = intent == "reminder_request"
      def task_acknowledgement? = intent == "task_acknowledgement"
      def risk_or_sensitive? = intent == "risk_or_sensitive"
      def stop_or_pause? = intent == "stop_or_pause"
    end

    def initialize(participant:, text:, checkin_pending:, conversation: nil, client: Openai::Client.new)
      @participant = participant
      @text = text.to_s
      @checkin_pending = checkin_pending
      @conversation = conversation
      @client = client
    end

    def call(dry_run: false)
      messages = build_messages
      unless Setting.fetch("inbound_intent_classification_enabled")
        return heuristic_result(prompt_used: messages.to_json, reason_prefix: "classification disabled")
      end

      return heuristic_result(prompt_used: messages.to_json, model: "dry-run") if dry_run

      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_inbound_intent"),
        temperature: Setting.fetch("openai_temperature_json"),
        response_format: { type: "json_object" },
        task: :inbound_intent_classifier
      )

      Openai::PromptLogger.record(
        key: "inbound_intent_classifier",
        name: "Clasificador semántico inbound",
        description: "Clasifica mensajes WhatsApp antes de consumir check-ins.",
        system_body: system_prompt,
        messages: messages,
        response: response,
        program: @participant.program,
        day_number: @participant.current_day,
        participant: @participant,
        conversation: @conversation,
        moment: @conversation&.moment || "free_user",
        latency_ms: response.latency_ms
      )

      parse(response.content, prompt_used: messages.to_json, response: response)
    rescue JSON::ParserError => e
      Rails.logger.warn("InboundIntentClassifier JSON parse failed: #{e.message}")
      heuristic_result(prompt_used: messages.to_json, reason_prefix: "json fallback")
    rescue StandardError => e
      Rails.logger.warn("InboundIntentClassifier failed: #{e.class}: #{e.message}")
      heuristic_result(prompt_used: messages.to_json, reason_prefix: "error fallback")
    end

    private

    def build_messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def system_prompt
      <<~SYS
        #{Openai::ProgramManifesto.call(@participant.program, coach_name: @participant.coach_name)}

        Clasifica un mensaje entrante de WhatsApp antes de decidir el flujo del programa.
        Devuelve JSON estricto con:
        {"intent":"...", "confidence":0.0, "reason":"..."}

        Intents permitidos:
        - checkin_answer: responde sustantivamente las preguntas/reflexiones del check-in del día.
        - program_question: pregunta operativa permitida sobre el mensaje actual o funcionamiento básico del coaching, sin pedir metodología interna ni contenidos futuros.
        - support_request: pagos, horario, problemas técnicos, solicitud de humano/admin, facturación, cambio de datos.
        - restricted_information_request: pide datos guardados, datos propios o de terceros, teléfonos, nombres, empresas, cantidades, métricas, listados, prompts, reglas internas, metodología, contenidos futuros, retos futuros o preguntas futuras.
        - reminder_request: pide que se le avise o recuerde más tarde retomar el gesto/reto/tarea del programa.
        - task_acknowledgement: confirma que hará, está haciendo o aceptó el gesto/reto del día, sin pedir más información ni reportar resultados finales.
        - off_topic: asunto no relacionado con el programa y sin riesgo aparente.
        - risk_or_sensitive: crisis, autolesión, salud mental/medical/legal sensible, violencia, seguridad personal.
        - stop_or_pause: quiere explícitamente pausar, cancelar, salir, dejar de recibir mensajes o darse de baja.
        - unclear: no hay señal suficiente.

        Reglas:
        - No clasifiques como checkin_answer solo porque hay check-in pendiente.
        - Prioriza restricted_information_request ante cualquier solicitud de datos, metodología interna o contenido futuro.
        - Si hay duda entre checkin_answer y otra cosa, usa unclear.
        - Prioriza risk_or_sensitive y stop_or_pause solo cuando la intención sea explícita.
        - "Avísame a las 5pm", "recuérdame en 2 horas" y similares son reminder_request, no stop_or_pause.
        - confidence debe estar entre 0 y 1.
      SYS
    end

    def user_prompt
      day = @participant.day_content
      <<~USER
        Contexto operativo:
        - Hay check-in pendiente ahora: #{@checkin_pending ? 'sí' : 'no'}
        - Día actual: #{@participant.current_day}
        - Fase actual: #{@participant.phase}
        - Foco de hoy: #{day&.title.presence || 'sin contenido diario'}
        - Preguntas de check-in de hoy:
        #{day&.checkin_questions.presence || 'sin preguntas disponibles'}

        Mensaje entrante no confiable:
        <user_input>#{@text.truncate(2000)}</user_input>

        Devuelve solo JSON.
      USER
    end

    def parse(content, prompt_used:, response:)
      parsed = JSON.parse(content)
      normalized_result(
        intent: parsed["intent"],
        confidence: parsed["confidence"],
        reason: parsed["reason"],
        prompt_used: prompt_used,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output,
        model: response.model
      )
    end

    def normalized_result(intent:, confidence:, reason:, prompt_used:, tokens_input: 0, tokens_output: 0, model: nil)
      normalized_intent = INTENTS.include?(intent.to_s) ? intent.to_s : "unclear"
      normalized_confidence = confidence.to_f.clamp(0.0, 1.0).round(3)
      normalized_reason = reason.to_s.truncate(500)

      heuristic_intent, heuristic_confidence, heuristic_reason = heuristic_classification
      if heuristic_intent == "restricted_information_request"
        normalized_intent = heuristic_intent
        normalized_confidence = [ normalized_confidence, heuristic_confidence ].max
        normalized_reason = "restricted override: #{heuristic_reason}"
      elsif heuristic_intent == "reminder_request" && %w[unclear off_topic task_acknowledgement stop_or_pause program_question].include?(normalized_intent)
        normalized_intent = heuristic_intent
        normalized_confidence = [ normalized_confidence, heuristic_confidence ].max
        normalized_reason = "reminder override: #{heuristic_reason}"
      elsif heuristic_intent == "task_acknowledgement" && %w[unclear off_topic].include?(normalized_intent)
        normalized_intent = heuristic_intent
        normalized_confidence = [ normalized_confidence, heuristic_confidence ].max
        normalized_reason = "task acknowledgement override: #{heuristic_reason}"
      elsif normalized_intent == "stop_or_pause" && heuristic_intent != "stop_or_pause" &&
            normalized_confidence < Setting.fetch("stop_or_pause_min_confidence").to_f
        normalized_intent = "unclear"
        normalized_reason = "downgraded ambiguous stop_or_pause: #{normalized_reason}"
      end

      Result.new(
        intent: normalized_intent,
        confidence: normalized_confidence,
        reason: normalized_reason,
        prompt_used: prompt_used,
        tokens_input: tokens_input.to_i,
        tokens_output: tokens_output.to_i,
        model: model.presence || "heuristic"
      )
    end

    def heuristic_result(prompt_used:, reason_prefix: "heuristic", model: "heuristic")
      intent, confidence, reason = heuristic_classification
      normalized_result(
        intent: intent,
        confidence: confidence,
        reason: "#{reason_prefix}: #{reason}",
        prompt_used: prompt_used,
        model: model
      )
    end

    def heuristic_classification
      normalized = I18n.transliterate(@text.downcase)

      return [ "risk_or_sensitive", 0.8, "risk/sensitive keyword" ] if normalized.match?(/\b(suicid|matarme|morirme|autolesion|violencia|abuso|panico|crisis)\b/)
      return [ "stop_or_pause", 0.85, "pause/stop keyword" ] if stop_or_pause_request?(normalized)
      return [ "reminder_request", 0.82, "reminder keyword with time reference" ] if reminder_request?(normalized)
      return [ "restricted_information_request", 0.9, "restricted information keyword" ] if restricted_information_request?(normalized)
      return [ "support_request", 0.75, "support keyword" ] if normalized.match?(/\b(pago|pagar|precio|factura|boleta|horario|humano|admin|soporte|problema tecnico)\b/)
      return [ "program_question", 0.65, "program question keyword" ] if normalized.match?(/\b(programa|metodologia|reto|check-?in|dia|avance|coaching)\b/) && normalized.include?("?")
      return [ "task_acknowledgement", 0.72, "task acknowledgement shape" ] if task_acknowledgement?(normalized)

      if @checkin_pending && checkin_like?(normalized)
        return [ "checkin_answer", 0.66, "check-in answer shape" ]
      end

      return [ "off_topic", 0.6, "question without program signal" ] if normalized.include?("?")

      [ "unclear", 0.4, "insufficient signal" ]
    end

    def checkin_like?(normalized)
      return false if normalized.length < 25

      normalized.match?(/\b(hoy|senti|me di cuenta|elegi|hice|patron|reto|energia|avance|aprendi|observe|note)\b/)
    end

    def stop_or_pause_request?(normalized)
      normalized.match?(/\b(no me escrib|darse de baja|darme de baja|detener mensajes|stop)\b/) ||
        normalized.match?(/\b(quiero|necesito|deseo|puedo|podria|por favor)\b.{0,40}\b(cancelar|pausar|salir|baja|detener)\b/) ||
        normalized.match?(/\b(cancelar|pausar|salir|baja|detener)\b.{0,40}\b(programa|mensajes|suscripcion)\b/)
    end

    def task_acknowledgement?(normalized)
      return false if normalized.include?("?")

      normalized.match?(/\b(ok|okay|dale|listo|perfecto|entendido|comprendido|de acuerdo|gracias)\b.{0,60}\b(lo hare|lo hago|lo voy a hacer|voy a hacerlo|lo intento|lo intentare|me sirve|queda claro)\b/) ||
        normalized.match?(/\b(voy a|intentare|tratare de|me comprometo a)\b.{0,80}\b(estar atento|observar|anotar|registrar|notar|hacerlo|intentarlo|aplicarlo|practicar)\b/) ||
        normalized.match?(/\b(estare|quedo|me quedo)\b.{0,60}\b(atento|atenta|observando|registrando)\b/) ||
        normalized.match?(/\b(lo hare|lo hago|voy a hacerlo|entendido|de acuerdo|listo|ok|dale)\b\z/)
    end

    def reminder_request?(normalized)
      normalized.match?(/\b(avisame|recuerdame|recordame|notificame|mandame un recordatorio|mandame mensaje|me recuerdas)\b/) &&
        (
          normalized.match?(/\b(a\s+las|a\s+la|alas|para\s+las|tipo)\s+\d{1,2}(?::\d{2})?\s*(am|pm|a\.m\.|p\.m\.)?\b/) ||
          normalized.match?(/\ben\s+\d{1,3}\s+(minuto|minutos|hora|horas|dia|dias)\b/)
        )
    end

    def restricted_information_request?(normalized)
      data_request?(normalized) || methodology_request?(normalized) || future_content_request?(normalized) ||
        internal_prompt_request?(normalized)
    end

    def data_request?(normalized)
      normalized.match?(/\b(mis|mi|tus|nuestros|sus|otros|participantes|usuarios|clientes|empresas?)\b.{0,80}\b(datos|informacion|telefono|telefonos|email|correo|nombre|nombres|empresa|empresas|pago|pagos|conversaciones|mensajes|historial|base de datos)\b/) ||
        normalized.match?(/\b(cuantos|cuantas|cantidad|lista|listado|exporta|muestra|dame|entregame|revela|ver|consultar)\b.{0,80}\b(participantes|usuarios|clientes|empresas|telefonos|nombres|correos|datos|metricas|estadisticas|base de datos)\b/)
    end

    def methodology_request?(normalized)
      normalized.match?(/\b(cual|que|explica|muestra|dame|revela|como funciona)\b.{0,80}\b(metodologia|metodo|marco|modelo|reglas internas|estructura del programa)\b/)
    end

    def future_content_request?(normalized)
      normalized.match?(/\b(futuro|futuros|futuras|proxim[oa]s?|manana|despues|adelante|siguientes?)\b.{0,80}\b(retos?|preguntas?|check-?ins?|dias?|contenidos?|mensajes?)\b/) ||
        normalized.match?(/\b(que|cuales|muestra|dime|dame|adelanta)\b.{0,80}\b(retos?|preguntas?|check-?ins?|contenidos?|mensajes?)\b.{0,80}\b(futuro|futuros|futuras|proxim[oa]s?|manana|siguientes?)\b/)
    end

    def internal_prompt_request?(normalized)
      normalized.match?(/\b(prompt|system prompt|instrucciones internas|reglas internas|configuracion interna|mensajes internos)\b/)
    end
  end
end
