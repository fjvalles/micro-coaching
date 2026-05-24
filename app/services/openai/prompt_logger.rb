module Openai
  class PromptLogger
    def self.record(key:, name:, system_body:, messages:, response: nil, **opts)
      new(key: key, name: name, system_body: system_body, messages: messages, response: response, **opts).record
    end

    def initialize(key:, name:, system_body:, messages:,
                   response: nil, output_body: nil, model_used: nil,
                   tokens_input: 0, tokens_output: 0, latency_ms: nil,
                   description: nil, program: nil, day_number: nil,
                   participant: nil, moment: nil, conversation: nil,
                   error_message: nil)
      @key = key.to_s
      @name = name
      @description = description
      @system_body = system_body.to_s
      @messages = messages
      @program = program
      @day_number = day_number
      @participant = participant
      @moment = moment&.to_s
      @conversation = conversation
      @error_message = error_message

      if response
        @output_body = response.respond_to?(:content) ? response.content : response.to_s
        @model_used = response.respond_to?(:model) ? response.model : nil
        @tokens_input = response.respond_to?(:tokens_input) ? response.tokens_input.to_i : 0
        @tokens_output = response.respond_to?(:tokens_output) ? response.tokens_output.to_i : 0
      else
        @output_body = output_body
        @model_used = model_used
        @tokens_input = tokens_input.to_i
        @tokens_output = tokens_output.to_i
      end
      @latency_ms = latency_ms
    end

    def record
      template = find_or_create_template
      version = sync_version(template)
      PromptExecution.create!(
        prompt_template: template,
        prompt_version: version,
        participant: @participant,
        conversation: @conversation,
        day_number: @day_number || @participant&.current_day,
        moment: @moment,
        rendered_messages: serialize_messages(@messages),
        output_body: @output_body,
        model_used: @model_used,
        tokens_input: @tokens_input,
        tokens_output: @tokens_output,
        latency_ms: @latency_ms,
        error_message: @error_message
      )
    rescue => e
      Rails.logger.warn("PromptLogger failed: #{e.class}: #{e.message}")
      nil
    end

    private

    def find_or_create_template
      PromptTemplate.find_or_create_by!(
        key: @key,
        program_id: @program&.id,
        day_number: day_number_for_template
      ) do |t|
        t.name = @name
        t.description = @description
        t.current_body = @system_body
        t.current_version = 0
        t.source = "service"
      end
    rescue ActiveRecord::RecordNotUnique
      PromptTemplate.find_by!(
        key: @key,
        program_id: @program&.id,
        day_number: day_number_for_template
      )
    end

    def day_number_for_template
      @key.start_with?("day_system_prompt") ? @day_number : nil
    end

    def sync_version(template)
      latest = template.latest_version
      if latest.nil? || latest.body != @system_body
        template.record_version!(body: @system_body, origin: "service", change_note: "auto-captured from service")
      else
        latest
      end
    end

    def serialize_messages(messages)
      Array(messages).map do |m|
        if m.is_a?(Hash)
          content = m[:content] || m["content"]
          { role: m[:role] || m["role"], content: content.is_a?(String) ? content : content.to_json }
        else
          { role: "raw", content: m.to_s }
        end
      end
    end
  end
end
