module Admin
  # Consolidated P&L: income (CLP, from authorized Payments) minus operating costs
  # (USD, from Finances::CostCalculator) converted to CLP via the manual
  # `usd_clp_rate` Setting. Income lives in CLP and costs in USD, so the rate is the
  # bridge. Read-only; same period filter as Finanzas / Ingresos.
  class ProfitLossController < BaseController
    include PeriodFilterable

    def index
      @period       = params[:period] || "this_month"
      @range        = period_range(@period)
      @period_label = period_label(@period)

      @rate     = Setting.fetch("usd_clp_rate").to_f
      @tax_rate = Setting.fetch("tax_rate").to_f

      # ── Income (CLP) — authorized payments in the period ──
      scope                 = Payment.in_period(@range)
      authorized            = scope.authorized
      @payment_count        = authorized.count
      @income_gross_clp     = authorized.sum(:amount)
      @income_iva_clp       = authorized.sum { |p| p.tax_amount(@tax_rate) }
      @income_net_clp       = @income_gross_clp - @income_iva_clp
      @commission_clp       = authorized.sum(:commission_amount)
      @income_received_clp  = authorized.sum(:net_amount) # bruto − comisión Transbank
      @payments             = scope.includes(:participant, :company).order(created_at: :desc).limit(100)

      # ── Costs (USD → CLP) ──
      costs            = Finances::CostCalculator.new(@range).call
      @ai_cost_usd     = costs.ai_total
      @manual_cost_usd = costs.manual_total
      @cost_usd        = costs.total_cost
      @cost_clp        = (@cost_usd * @rate).round
      @period_months   = costs.period_months

      @ai_by_model       = costs.ai_by_model
      @ai_by_participant = costs.ai_by_participant
      @ai_by_program     = costs.ai_by_program
      @ai_total          = costs.ai_total
      @ai_tokens_in      = costs.ai_tokens_in
      @ai_tokens_out     = costs.ai_tokens_out
      @ai_calls          = costs.ai_calls
      @manual_monthly    = costs.manual_monthly
      @manual_total      = costs.manual_total
      @total_cost        = costs.total_cost

      participants_in_period = Participant.kept
        .where("enrolled_at <= ? AND (completed_at IS NULL OR completed_at >= ?)", @range.end, @range.begin)
      @participant_count = participants_in_period.count
      @program_count     = Program.where(active: true).count

      @avg_monthly     = @period_months > 0 ? @total_cost / @period_months : 0
      @avg_participant = @participant_count > 0 ? @total_cost / @participant_count : 0
      @avg_program     = @program_count > 0 ? @total_cost / @program_count : 0

      # ── Margin ── cash received (after commission) minus operating costs, in CLP.
      @margin_clp = @income_received_clp - @cost_clp
      @margin_pct = @income_received_clp.positive? ? (@margin_clp.to_f / @income_received_clp * 100).round(1) : nil
    end
  end
end
