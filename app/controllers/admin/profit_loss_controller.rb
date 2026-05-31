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
      authorized            = Payment.in_period(@range).authorized
      @payment_count        = authorized.count
      @income_gross_clp     = authorized.sum(:amount)
      @income_iva_clp       = authorized.sum { |p| p.tax_amount(@tax_rate) }
      @income_net_clp       = @income_gross_clp - @income_iva_clp
      @commission_clp       = authorized.sum(:commission_amount)
      @income_received_clp  = authorized.sum(:net_amount) # bruto − comisión Transbank

      # ── Costs (USD → CLP) ──
      costs            = Finances::CostCalculator.new(@range).call
      @ai_cost_usd     = costs.ai_total
      @manual_cost_usd = costs.manual_total
      @cost_usd        = costs.total_cost
      @cost_clp        = (@cost_usd * @rate).round
      @period_months   = costs.period_months

      # ── Margin ── cash received (after commission) minus operating costs, in CLP.
      @margin_clp = @income_received_clp - @cost_clp
      @margin_pct = @income_received_clp.positive? ? (@margin_clp.to_f / @income_received_clp * 100).round(1) : nil
    end
  end
end
