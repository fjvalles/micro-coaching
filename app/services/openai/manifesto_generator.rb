module Openai
  class ManifestoGenerator
    Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, client: Openai::Client.new)
      @participant = participant
      @client = client
    end

    def call
      messages = build_messages
      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_manifesto"),
        temperature: Setting.fetch("openai_temperature_generative"),
        task: :manifesto
      )

      Openai::PromptLogger.record(
        key: "manifesto", name: "Manifiesto de cierre",
        description: "Manifiesto día 15 (cierre del programa).",
        system_body: messages.first[:content], messages: messages, response: response,
        program: @participant.program, day_number: @participant.current_day,
        participant: @participant, moment: "manifesto", latency_ms: response.latency_ms
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
      reports = @participant.daily_reports.chronological.map do |r|
        "Día #{r.day_number}: #{r.ai_summary.presence || r.raw_text.to_s.truncate(160)}"
      end.join("\n")

      [
        { role: "system", content: <<~SYS },
          #{Openai::ProgramManifesto.call(@participant.program, coach_name: @participant.coach_name)}

          Vas a generar el MANIFIESTO DE CIERRE — una pieza personal, escrita en segunda
          persona, de 120 a 200 palabras, sin títulos ni viñetas, que recoja la carta del
          participante y los patrones clave de sus días en el programa.
        SYS
        { role: "user", content: <<~USER }
          Participante: #{@participant.name}
          Patrón inicial declarado: #{@participant.initial_pattern}

          Reportes diarios:
          #{reports}

          Carta del Día 13 (entrada principal):
          #{@participant.daily_reports.find_by(day_number: 13)&.raw_text}

          Escribe el manifiesto de cierre.
        USER
      ]
    end
  end
end
