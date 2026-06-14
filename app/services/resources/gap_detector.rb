module Resources
  class GapDetector
    Result = Struct.new(:needed, :topic, :kind, :reason, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true) do
      def needed? = needed
    end

    def initialize(participant:, text:, client: Openai::Client.new)
      @participant = participant
      @text = text.to_s
      @client = client
    end

    def call
      messages = build_messages
      response = @client.chat(
        messages: messages,
        max_tokens: 220,
        temperature: Setting.fetch("openai_temperature_json"),
        response_format: { type: "json_object" },
        task: :resource_gap_detector
      )

      parsed = JSON.parse(response.content)
      Result.new(
        needed: ActiveModel::Type::Boolean.new.cast(parsed["needed"]),
        topic: parsed["topic"].to_s,
        kind: Resource.kinds.key?(parsed["kind"].to_s) ? parsed["kind"].to_s : "article",
        reason: parsed["reason"].to_s,
        prompt_used: messages.to_json,
        tokens_input: response.tokens_input,
        tokens_output: response.tokens_output,
        model: response.model
      )
    rescue JSON::ParserError => e
      Rails.logger.warn("Resources::GapDetector parse failed: #{e.message}")
      Result.new(needed: false, topic: nil, kind: nil, reason: "parse_failed")
    end

    private

    def build_messages
      [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    end

    def system_prompt
      <<~PROMPT
        Eres un analista de una conversación de coaching. Decide si haría falta
        proponer un recurso externo curado para apoyar a la persona.
        Responde solo JSON: {"needed": boolean, "topic": "tema concreto", "kind": "article|video", "reason": "breve"}.
        Marca needed=false si bastaría una respuesta conversacional o si el tema es sensible/privado.
      PROMPT
    end

    def user_prompt
      <<~PROMPT
        Participante: #{@participant.name}
        Programa: #{@participant.program&.name || "general"}
        Mensaje:
        <message>
        #{@text.truncate(2000)}
        </message>
      PROMPT
    end
  end
end
