module Participants
  class ManualCheckinAssignment
    Result = Struct.new(:ok, :reason, :daily_report, :conversations, keyword_init: true) do
      def ok? = ok
    end

    def initialize(participant:, conversation_ids:, admin_user: nil)
      @participant = participant
      @conversation_ids = Array(conversation_ids).reject(&:blank?).uniq
      @admin_user = admin_user
    end

    def call
      return failure(:not_overdue) unless @participant.overdue_checkin_pending?
      return failure(:blank_selection) if @conversation_ids.empty?

      conversations = selected_conversations
      return failure(:invalid_selection) unless conversations.size == @conversation_ids.size
      return failure(:invalid_selection) unless conversations.all? { |conversation| eligible?(conversation) }

      raw_text = combined_text(conversations)
      return failure(:blank_body) if raw_text.blank?

      result = Openai::CheckinSummarizer.new(
        participant: @participant,
        day_content: @participant.day_content,
        raw_text: raw_text
      ).call

      daily_report = persist_assignment!(conversations, raw_text, result)
      return failure(:already_resolved) unless daily_report

      Result.new(ok: true, daily_report: daily_report, conversations: conversations)
    end

    private

    def selected_conversations
      @participant.conversations.kept
                  .where(id: @conversation_ids)
                  .order(:created_at)
                  .to_a
    end

    def eligible?(conversation)
      conversation.user? &&
        conversation.day_number == @participant.current_day &&
        conversation.created_at >= @participant.pending_checkin_at &&
        !conversation.checkin_response?
    end

    def combined_text(conversations)
      conversations.filter_map do |conversation|
        text = conversation.transcription.presence || conversation.body.to_s
        text.strip.presence
      end.join("\n\n")
    end

    def persist_assignment!(conversations, raw_text, result)
      ActiveRecord::Base.transaction do
        @participant.lock!
        raise ActiveRecord::Rollback unless @participant.overdue_checkin_pending?

        conversations.each do |conversation|
          conversation.update!(
            moment: :checkin_response,
            day_number: @participant.current_day,
            inbound_intent: "checkin_answer",
            inbound_intent_confidence: 1.0,
            inbound_intent_reason: "Asignado manualmente por #{@admin_user&.email || 'admin'}"
          )
        end

        daily_report = DailyReport.create!(
          participant: @participant,
          day_number: @participant.current_day,
          raw_text: raw_text,
          ai_summary: result.summary,
          ai_key_pattern: result.key_pattern,
          reported_at: Time.current
        )

        PaperTrail.request(whodunnit: @admin_user&.email || "admin", controller_info: { source: "admin" }) do
          @participant.update!(pending_checkin_at: nil)
        end

        daily_report
      end
    end

    def failure(reason)
      Result.new(ok: false, reason: reason)
    end
  end
end
