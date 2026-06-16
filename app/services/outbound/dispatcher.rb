module Outbound
  # Central decision point for "send now" vs "queue for admin".
  # Resolves response mode for the participant and either:
  #   - auto    → sends through Whatsapp::Client / TemplateSender and writes a Conversation
  #   - approve → builds AI draft and queues PendingResponse (status: pending)
  #   - suggest → same as approve (admin can edit before sending)
  #   - manual  → queues empty PendingResponse w/ original AI body as hint (no AI call required upstream)
  #
  # Returns a Result struct with :delivered (boolean), :conversation, :pending_response.
  class Dispatcher
    Result = Struct.new(:delivered, :conversation, :pending_response, keyword_init: true) do
      def delivered? = delivered
      def queued?    = pending_response.present? && !delivered
    end

    def initialize(participant:, moment:, day_number: nil, mode: nil)
      @participant = participant
      @moment      = moment.to_s
      @day_number  = day_number || participant.current_day
      @mode        = mode || ResponseMode.for(participant)
    end

    # Send a free-form text. ai meta optional (prompt_used/tokens/model).
    def send_text(body:, ai: {}, resource_id: nil, preview_url: false)
      prepared = prepare_text(body, resource_id, ai, preview_url)

      if @mode == "auto"
        convo = deliver_text(prepared.body, ai, preview_url: prepared.preview_url)
        record_resource_delivery(prepared.resource, convo)
        Result.new(delivered: convo.sent_at.present?, conversation: convo)
      else
        pending = queue(
          draft_body: prepared.body,
          delivery_kind: "text",
          ai: ai
        )
        notify(pending)
        Result.new(delivered: false, pending_response: pending)
      end
    end

    def send_template(template_name:, variables: [], body_preview: nil, ai: {})
      if @mode == "auto"
        convo = deliver_template(template_name, variables)
        Result.new(delivered: convo.sent_at.present?, conversation: convo)
      else
        pending = queue(
          draft_body: body_preview.presence || variables.join(" | "),
          delivery_kind: "template",
          template_name: template_name,
          template_variables: variables,
          ai: ai
        )
        notify(pending)
        Result.new(delivered: false, pending_response: pending)
      end
    end

    private

    def deliver_text(body, ai, preview_url: false)
      response = Whatsapp::Client.new.send_text(
        to: @participant.phone_e164,
        body: body,
        preview_url: preview_url
      )
      Conversation.create!(
        participant: @participant,
        day_number: @day_number,
        moment: @moment,
        role: :assistant,
        body: body,
        whatsapp_message_id: response.wamid,
        sent_at: response.success? ? Time.current : nil,
        error_message: response.success? ? nil : response.error,
        prompt_used: ai[:prompt_used],
        tokens_input: ai[:tokens_input],
        tokens_output: ai[:tokens_output],
        model_used: ai[:model_used] || ai[:model]
      )
    end

    def prepare_text(body, resource_id, ai, preview_url)
      if ai[:resource_catalog] || resource_id.present?
        Resources::MessageBuilder.new(
          body: body,
          resource_id: resource_id,
          program: @participant.program
        ).call
      else
        Resources::MessageBuilder::Result.new(body: body.to_s, resource: nil, preview_url: preview_url)
      end
    end

    def record_resource_delivery(resource, conversation)
      return unless resource && conversation&.persisted? && conversation.sent_at.present?

      ResourceDelivery.create!(
        resource: resource,
        participant: @participant,
        conversation: conversation,
        moment: @moment
      )
    end

    def deliver_template(template_name, variables)
      Whatsapp::TemplateSender.new(
        participant: @participant,
        template_name: template_name,
        moment: @moment,
        day_number: @day_number,
        variables: variables
      ).call
    end

    def queue(draft_body:, delivery_kind:, ai: {}, template_name: nil, template_variables: [])
      PendingResponse.create!(
        participant: @participant,
        mode: @mode,
        moment: @moment,
        day_number: @day_number,
        draft_body: draft_body.to_s,
        original_body: draft_body.to_s,
        delivery_kind: delivery_kind,
        template_name: template_name,
        template_variables: template_variables,
        prompt_used: ai[:prompt_used],
        tokens_input: ai[:tokens_input],
        tokens_output: ai[:tokens_output],
        model_used: ai[:model_used] || ai[:model],
        status: "pending"
      )
    end

    def notify(pending)
      PendingResponseMailerJob.perform_later(pending.id)
    rescue StandardError => e
      Rails.logger.warn("PendingResponse notify failed: #{e.message}")
    end
  end
end
