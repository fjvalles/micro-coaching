module Openai
  # Maintains a rolling, AI-authored profile of the participant for coaching
  # continuity. Re-runs after each check-in, folding the prior summary together
  # with recent reports and dominant skills into a fresh abstracted summary that
  # is injected back into the generative prompts. This is the participant-memory
  # loop: what older messages drop out of the 5-message window, the summary keeps.
  #
  # AI-SAFE by construction: the output is an abstracted behavioral/progress note,
  # never raw exposing facts. It never sees coach_notes. Internal analyzer, so it
  # does not prepend ProgramManifesto (no shared-cache benefit; mirrors PromptCritic).
  class ParticipantSummarizer
    Result = Struct.new(:summary, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    RECENT_REPORTS = 6

    def initialize(participant:, client: Openai::Client.new)
      @participant = participant
      @client = client
    end

    def call
      messages = build_messages
      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_summary"),
        temperature: Setting.fetch("openai_temperature_json"),
        task: :participant_summary
      )

      Openai::PromptLogger.record(
        key: "participant_summary", name: "Resumen del participante",
        description: "Perfil rodante del participante para continuidad de coaching.",
        system_body: messages.first[:content], messages: messages, response: response,
        program: @participant.program, day_number: @participant.current_day,
        participant: @participant, moment: "participant_summary", latency_ms: response.latency_ms
      )

      Result.new(
        summary: response.content,
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
          Mantienes un perfil breve y evolutivo de un participante en un programa de
          coaching conductual, para dar continuidad entre conversaciones. Recibes el
          resumen previo (si existe) y señales recientes. Devuelve UN resumen actualizado
          en español, en tercera persona, máximo 150 palabras.

          Incluye: hacia dónde avanza, qué le está funcionando, qué se le dificulta,
          tono emocional general y temas recurrentes — siempre en términos de conducta
          observada y progreso.

          NO incluyas etiquetas clínicas, diagnósticos, ni datos sensibles crudos. NO
          inventes. Si no hay señal suficiente, devuelve un resumen corto y prudente.
          Devuelve solo el texto del resumen, sin encabezados ni comillas.
        SYS
        { role: "user", content: user_content }
      ]
    end

    def user_content
      <<~USER
        Día actual: #{@participant.current_day} (fase #{@participant.phase})

        Resumen previo:
        #{@participant.ai_summary.to_s.truncate(800).presence || '(sin resumen previo)'}

        Habilidades dominantes recientes: #{dominant_skill_names.presence || 'sin datos'}

        Reportes recientes (más nuevo primero):
        #{recent_reports_text.presence || '(sin reportes)'}

        Actualiza el resumen del participante.
      USER
    end

    def dominant_skill_names
      @participant.dominant_skills(limit: 3).map(&:name).join(", ")
    end

    def recent_reports_text
      @participant.daily_reports.order(reported_at: :desc).limit(RECENT_REPORTS).map do |r|
        "Día #{r.day_number}: #{r.ai_summary.to_s.truncate(160)}" \
          "#{r.ai_key_pattern.present? ? " — patrón: #{r.ai_key_pattern.to_s.truncate(80)}" : ''}"
      end.join("\n")
    end
  end
end
