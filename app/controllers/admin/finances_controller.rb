module Admin
  class FinancesController < BaseController
    include PeriodFilterable

    def index
      @period = params[:period] || "this_month"
      @range  = period_range(@period)
      @period_label = period_label(@period)

      costs           = Finances::CostCalculator.new(@range).call
      @ai_by_model    = costs.ai_by_model
      @ai_total       = costs.ai_total
      @ai_tokens_in   = costs.ai_tokens_in
      @ai_tokens_out  = costs.ai_tokens_out
      @ai_calls       = costs.ai_calls
      @manual_monthly = costs.manual_monthly
      @manual_total   = costs.manual_total
      @total_cost     = costs.total_cost
      @period_months  = costs.period_months

      participants_in_period = Participant.kept
        .where("enrolled_at <= ? AND (completed_at IS NULL OR completed_at >= ?)", @range.end, @range.begin)
      @participant_count = participants_in_period.count
      @program_count     = Program.where(active: true).count

      @avg_monthly     = @period_months > 0 ? @total_cost / @period_months : 0
      @avg_participant = @participant_count > 0 ? @total_cost / @participant_count : 0
      @avg_program     = @program_count > 0 ? @total_cost / @program_count : 0
    end
  end
end
