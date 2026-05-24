module Openai
  class CheckinSummarizer
    Result = Struct.new(:summary, :key_pattern, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, day_content:, raw_text:, client: Openai::Client.new)
      @participant = participant
      @day_content = day_content
      @raw_text = raw_text
      @client = client
    end

    def call
      messages = build_messages
      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_checkin"),
        temperature: Setting.fetch("openai_temperature_json"),
        response_format: { type: "json_object" }
      )

      summary, key_pattern = parse(response.content)
      Result.new(
        summary: summary,
        key_pattern: key_pattern,
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
          #{Openai.program_manifesto(@participant.program)}

          Tu tarea es resumir el check-in nocturno del participante en JSON estricto.
          Devuelve exactamente: {"summary": "...", "key_pattern": "..."}.
          - summary: una frase en español (max 25 palabras) que capture lo central.
          - key_pattern: el patrón automático principal identificado hoy (frase corta).
        SYS
        { role: "user", content: <<~USER }
          Día: #{@day_content.day_number} — #{@day_content.title}
          Preguntas:
          #{@day_content.checkin_questions}

          Respuesta del participante:
          #{@raw_text}

          Devuelve solo el JSON.
        USER
      ]
    end

    def parse(content)
      json = JSON.parse(content)
      [ json["summary"].to_s, json["key_pattern"].to_s ]
    rescue JSON::ParserError => e
      Rails.logger.warn("CheckinSummarizer JSON parse failed: #{e.message}")
      [ content.to_s.truncate(200), nil ]
    end
  end
end
