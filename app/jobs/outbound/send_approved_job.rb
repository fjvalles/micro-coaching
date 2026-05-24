module Outbound
  class SendApprovedJob < ApplicationJob
    queue_as :default

    def perform(pending_id, admin_user_id = nil)
      pending = PendingResponse.kept.find(pending_id)
      return if pending.sent? || pending.rejected?

      conversation = if pending.delivery_kind == "template"
                       send_template(pending)
      else
                       send_text(pending)
      end

      pending.update!(
        status: "sent",
        conversation: conversation,
        approved_by_id: admin_user_id || pending.approved_by_id,
        acted_at: Time.current
      )
    end

    private

    def send_text(pending)
      response = Whatsapp::Client.new.send_text(to: pending.participant.phone_e164, body: pending.draft_body)
      Conversation.create!(
        participant: pending.participant,
        day_number: pending.day_number,
        moment: pending.moment,
        role: :assistant,
        body: pending.draft_body,
        whatsapp_message_id: response.wamid,
        sent_at: response.success? ? Time.current : nil,
        error_message: response.success? ? nil : response.error,
        prompt_used: pending.prompt_used,
        tokens_input: pending.tokens_input,
        tokens_output: pending.tokens_output,
        model_used: pending.model_used
      )
    end

    def send_template(pending)
      variables = if pending.draft_body != pending.original_body && pending.template_variables.is_a?(Array)
                    rebuild_variables(pending)
      else
                    pending.template_variables
      end

      Whatsapp::TemplateSender.new(
        participant: pending.participant,
        template_name: pending.template_name,
        moment: pending.moment,
        day_number: pending.day_number,
        variables: variables
      ).call
    end

    # If admin edited the draft for a template, swap the last variable (usually the AI body).
    def rebuild_variables(pending)
      vars = pending.template_variables.dup
      vars[-1] = pending.draft_body if vars.any?
      vars
    end
  end
end
