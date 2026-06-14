module Openai
  # Day-14 upsell message. Builds the day1→day14 contrast from the participant's own
  # arc and frames the offer as "unlock your investment" (Hooked): the 14 free days
  # are stored value, the personalized Nivel 2 is built from it. The model owns the
  # STORY only — price, founder-window deadline, links and guarantee are appended
  # deterministically by SendNivel2OfferJob so the model can never invent terms.
  #
  # Generative + participant-facing → prepends ProgramManifesto (coach identity +
  # prompt caching), temperature 0.75. Reuses the manifesto token budget (comparable
  # length, ~150-200 words).
  class Nivel2OfferGenerator
    Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, client: Openai::Client.new)
      @participant = participant
      @client = client
    end

    def call(dry_run: false)
      messages = build_messages
      if dry_run
        return Result.new(body: stub_body, prompt_used: messages.to_json,
                          tokens_input: 0, tokens_output: 0, model: "dry-run")
      end

      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_manifesto"),
        temperature: Setting.fetch("openai_temperature_generative"),
        task: :nivel2_offer
      )

      Openai::PromptLogger.record(
        key: "nivel2_offer", name: "Oferta Nivel 2",
        description: "Upsell de día 14: contraste día 1→14 e invitación a diseñar el Nivel 2.",
        system_body: messages.first[:content], messages: messages, response: response,
        program: @participant.program, day_number: @participant.current_day,
        participant: @participant, moment: "nivel2_offer", latency_ms: response.latency_ms
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
        { role: "system", content: <<~SYS },
          #{Openai::ProgramManifesto.call(@participant.program, coach_name: @participant.coach_name)}

          Vas a generar un MENSAJE DE INVITACIÓN para que el participante continúe con un
          programa personalizado de siguiente nivel (Nivel 2), justo al terminar su
          programa gratuito de 14 días.

          Enfoque obligatorio: enmarca la oferta como "desbloquear lo que ya construiste".
          Los 14 días fueron una inversión; el Nivel 2 se arma a partir de lo que el
          participante ya mostró. Abre con un contraste breve y concreto entre cómo llegó
          (su patrón inicial) y dónde está hoy, usando sus propios datos. Tono cálido, en
          segunda persona, 90 a 150 palabras, sin títulos ni viñetas.

          NO inventes precios, plazos, enlaces ni garantías: el sistema agrega esos
          términos después de tu mensaje. Cierra invitando a diseñar su Nivel 2, sin
          mencionar montos.
        SYS
        { role: "user", content: <<~USER }
          Participante: #{@participant.name}
          Patrón inicial declarado: #{@participant.initial_pattern.to_s.truncate(500).presence || 'no declarado'}
          Memoria acumulada del participante: #{@participant.ai_summary.to_s.truncate(700).presence || 'sin memoria acumulada'}
          Habilidades que más afloraron: #{dominant_skill_names.presence || 'sin datos'}
          Mapa de energía: #{(@participant.energy_map.presence || {}).to_json}

          Reportes diarios (su recorrido):
          #{reports_block.presence || 'sin reportes'}

          Escribe el mensaje de invitación al Nivel 2.
        USER
      ]
    end

    def reports_block
      @participant.daily_reports.chronological.map do |r|
        "Día #{r.day_number}: #{r.ai_summary.presence || r.raw_text.to_s.truncate(140)}"
      end.join("\n")
    end

    def dominant_skill_names
      @participant.dominant_skills(limit: 3).map(&:name).join(", ")
    end

    def stub_body
      "#{@participant.name}, mira lo que construiste en estos 14 días. " \
        "Tu Nivel 2 personalizado parte justo de aquí."
    end
  end
end
