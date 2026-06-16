module Whatsapp
  class TemplateSender
    def initialize(participant:, template_name:, moment:, day_number: nil, variables: [], client: Whatsapp::Client.new)
      @participant = participant
      @template_name = template_name
      @moment = moment
      @day_number = day_number || participant.current_day
      @variables = variables
      @client = client
    end

    def call
      components = build_components
      response = @client.send_template(
        to: @participant.phone_e164,
        template_name: @template_name,
        components: components
      )

      Conversation.create!(
        participant: @participant,
        day_number: @day_number,
        moment: @moment,
        role: :assistant,
        body: components_text,
        whatsapp_template_name: @template_name,
        whatsapp_message_id: response.wamid,
        sent_at: response.success? ? Time.current : nil,
        error_message: response.success? ? nil : response.error
      )
    end

    private

    def build_components
      return [] if @variables.empty?

      [ {
        type: "body",
        parameters: @variables.map { |v| { type: "text", text: template_parameter_text(v) } }
      } ]
    end

    def template_parameter_text(value)
      value.to_s.gsub(/[[:space:]]+/, " ").strip
    end

    def components_text
      "[template:#{@template_name}] #{@variables.map { |v| template_parameter_text(v) }.join(' | ')}"
    end
  end
end
