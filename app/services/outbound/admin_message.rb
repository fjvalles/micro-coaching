module Outbound
  # Admin-initiated manual send (free text or curated template) from the panel.
  # Wraps Outbound::Dispatcher with mode "auto" (the admin IS the human reviewer,
  # so it sends immediately — never queues a PendingResponse) and moment :admin_manual.
  #
  # Not idempotency-guarded on purpose: an admin may legitimately send several
  # messages in a row. Use it from both the controller (single, sync) and
  # SendAdminMessageJob (broadcast, async).
  #
  # Returns a Result with :sent? and a :skipped_reason symbol when it didn't send:
  #   :blank_body          — text kind with empty body
  #   :no_template         — template kind with no template_name
  #   :outside_24h_window  — Meta forbids free-form text outside the 24h window
  #   :send_failed         — Meta/kill-switch rejected the send (see error)
  class AdminMessage
    KINDS = %w[text template].freeze

    Result = Struct.new(:sent, :skipped_reason, :conversation, :error, keyword_init: true) do
      def sent? = sent
    end

    def initialize(participant:, kind:, body: nil, template_name: nil, variables: [])
      @participant   = participant
      @kind          = kind.to_s
      @body          = body.to_s
      @template_name = template_name.to_s
      @variables     = Array(variables).map(&:to_s).reject(&:blank?)
    end

    def call
      case @kind
      when "text"     then send_text
      when "template" then send_template
      else                 Result.new(sent: false, skipped_reason: :unknown_kind)
      end
    end

    private

    def send_text
      return Result.new(sent: false, skipped_reason: :blank_body) if @body.blank?
      return Result.new(sent: false, skipped_reason: :outside_24h_window) unless @participant.in_24h_window?

      finalize(dispatcher.send_text(body: @body).conversation)
    end

    def send_template
      return Result.new(sent: false, skipped_reason: :no_template) if @template_name.blank?

      convo = dispatcher.send_template(
        template_name: @template_name,
        variables: @variables,
        body_preview: @variables.join(" | ")
      ).conversation
      finalize(convo)
    end

    # A delivered Conversation carries sent_at only on a successful Meta send;
    # error_message holds the failure (kill-switch, 4xx/5xx).
    def finalize(convo)
      if convo&.sent_at.present?
        Result.new(sent: true, conversation: convo)
      else
        Result.new(sent: false, skipped_reason: :send_failed, conversation: convo, error: convo&.error_message)
      end
    end

    def dispatcher
      Outbound::Dispatcher.new(participant: @participant, moment: :admin_manual, mode: "auto")
    end
  end
end
