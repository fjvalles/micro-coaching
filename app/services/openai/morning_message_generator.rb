module Openai
  class MorningMessageGenerator
    Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, day_content:, client: Openai::Client.new)
      @participant = participant
      @day_content = day_content
      @client = client
    end

    def call(dry_run: false)
      messages = build_messages
      if dry_run
        return Result.new(body: @day_content.morning_template.to_s.gsub("{name}", @participant.name),
                          prompt_used: messages.to_json, tokens_input: 0, tokens_output: 0, model: "dry-run")
      end

      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_morning"),
        temperature: Setting.fetch("openai_temperature_generative"),
        task: :morning_message
      )

      Openai::PromptLogger.record(
        key: "morning_message", name: "Mensaje de despertar",
        description: "Mensaje matutino personalizado por día.",
        system_body: system_prompt, messages: messages, response: response,
        program: @participant.program, day_number: @participant.current_day,
        participant: @participant, moment: "morning_wake", latency_ms: response.latency_ms
      )

      Result.new(
        body: response.content,
        prompt_used: messages.to_json,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output,
        model: response.model
      )
    end

    private

    def build_messages
      [
        { role: "system", content: system_prompt },
        { role: "user",   content: user_prompt }
      ]
    end

    def system_prompt
      [
        Openai::ProgramManifesto.call(@participant.program, coach_name: @participant.coach_name),
        @day_content.ai_system_prompt.to_s,
        Skills::CoachingHint.for(@participant)
      ].compact_blank.join("\n\n")
    end

    # NOTE: coach_notes is intentionally NEVER included. focus_hint and ai_summary
    # are the AI-safe abstracted memory; coach_notes stays admin-only.
    def user_prompt
      <<~PROMPT
        Participante: #{@participant.name}
        Día: #{@participant.current_day} (#{@participant.phase})
        Patrón inicial: #{@participant.initial_pattern.to_s.truncate(500).presence || 'no declarado'}
        Foco de coaching: #{@participant.focus_hint.to_s.truncate(500).presence || 'general'}
        Mapa de energía: #{(@participant.energy_map.presence || {}).to_json}
        Memoria del participante: #{@participant.ai_summary.to_s.truncate(500).presence || 'sin memoria acumulada aún'}
        Último reporte (ayer): #{@participant.latest_report&.raw_text.to_s.truncate(500).presence || 'sin reporte previo'}
        Plantilla base (puedes reescribir manteniendo intención):
        #{@day_content.morning_template}

        Genera el mensaje de despertar de hoy, personalizado, refiriendo brevemente al
        reporte de ayer si existe. Máximo 4 frases. Sustituye {name} por el nombre real.
      PROMPT
    end
  end
end
