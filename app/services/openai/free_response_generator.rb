module Openai
  class FreeResponseGenerator
    Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, user_message:, client: Openai::Client.new)
      @participant = participant
      @user_message = user_message
      @client = client
    end

    def call
      messages = build_messages
      response = @client.chat(
        messages: messages,
        max_tokens: Setting.fetch("openai_max_tokens_free"),
        temperature: Setting.fetch("openai_temperature_generative")
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
      msgs = [ { role: "system", content: system_prompt } ]
      recent_history.each do |conv|
        msgs << { role: conv.role == "assistant" ? "assistant" : "user", content: conv.body.to_s }
      end
      msgs << { role: "user", content: @user_message.to_s }
      msgs
    end

    def system_prompt
      day = @participant.day_content
      <<~SYS
        #{Openai.program_manifesto(@participant.program)}

        Contexto del participante:
        - Nombre: #{@participant.name}
        - Día actual: #{@participant.current_day} (fase #{@participant.phase})
        - Patrón inicial: #{@participant.initial_pattern.presence || 'no declarado'}
        - Último reporte: #{@participant.latest_report&.raw_text.presence || 'sin reportes'}

        #{day ? "Foco de hoy: #{day.title}\n#{day.ai_system_prompt}" : ''}
      SYS
    end

    def recent_history
      @participant.conversations.kept
        .where(role: %w[user assistant])
        .order(created_at: :desc)
        .limit(5)
        .reverse
    end
  end
end
