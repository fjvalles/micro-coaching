module Admin
  class DashboardController < BaseController
    def index
      # Basic participant counts
      @active_participants_count = Participant.kept.active.count
      @pending_participants_count = Participant.kept.pending.count
      @completed_participants_count = Participant.kept.completed.count
      @total_participants_count = Participant.kept.count

      # Message counts and deliverability
      @messages_today_count = Conversation.kept.where("created_at >= ?", Time.current.beginning_of_day).count
      @failed_messages_count = Conversation.kept.failed.count
      @total_conversations_count = Conversation.kept.count

      # Advanced KPI 1: Active Response / Engagement Rate (last 24 hours)
      @engagement_rate = if @active_participants_count > 0
        replied_count = DailyReport.where("created_at >= ?", 24.hours.ago).distinct.count(:participant_id)
        ((replied_count.to_f / @active_participants_count) * 100).round(1)
      else
        0.0
      end

      # Advanced KPI 2: WhatsApp Deliverability & Read Rates
      @total_outgoing_count = Conversation.kept.where(role: :assistant).count
      @delivered_count = Conversation.kept.where(role: :assistant).where.not(delivered_at: nil).count
      @read_count = Conversation.kept.where(role: :assistant).where.not(read_at: nil).count

      @delivery_rate = @total_outgoing_count > 0 ? ((@delivered_count.to_f / @total_outgoing_count) * 100).round(1) : 0.0
      @read_rate = @total_outgoing_count > 0 ? ((@read_count.to_f / @total_outgoing_count) * 100).round(1) : 0.0

      # Advanced KPI 3: OpenAI Usage & Running Cost Estimate (assuming GPT-4o-mini rates)
      @total_input_tokens = Conversation.kept.sum(:tokens_input) || 0
      @total_output_tokens = Conversation.kept.sum(:tokens_output) || 0
      @total_tokens = @total_input_tokens + @total_output_tokens
      # GPT-4o-mini: Input $0.15 / 1M tokens, Output $0.60 / 1M tokens
      @estimated_openai_cost = (@total_input_tokens * 0.15 / 1_000_000.0) + (@total_output_tokens * 0.60 / 1_000_000.0)
      @formatted_openai_cost = "$%.3f USD" % @estimated_openai_cost

      # Visual Cohort Progress (days 1 to 14 distribution)
      @cohort_distribution = Participant.kept.active.group(:current_day).count
      @max_cohort_count = [ @cohort_distribution.values.max || 1, 1 ].max

      # Actionable Insight 1: Stuck/Inactive Active Participants (no user messages in the last 3 days, enrolled > 3 days ago)
      @stuck_participants = Participant.kept.active
        .where("created_at < ?", 3.days.ago)
        .where("NOT EXISTS (
          SELECT 1 FROM conversations
          WHERE conversations.participant_id = participants.id
            AND conversations.role = ?
            AND conversations.created_at >= ?
        )", Conversation.roles[:user], 3.days.ago)
        .order(updated_at: :desc)
        .limit(5)

      # Actionable Insight 2: Recent Delivery Errors
      @recent_failures = Conversation.kept.failed.includes(:participant).order(created_at: :desc).limit(5)

      # Logs (with preloading to prevent N+1)
      @recent_participants = Participant.kept.order(created_at: :desc).limit(5)
      @recent_messages = Conversation.kept.includes(:participant).chronological.last(5).reverse
    end
  end
end
