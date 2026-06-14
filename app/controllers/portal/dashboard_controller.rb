module Portal
  class DashboardController < BaseController
    def show
      @participant = current_participant
      @total_days  = @participant.program&.total_days || 14
      @pct = @total_days.positive? ? [ (@participant.current_day.to_f / @total_days * 100).round, 100 ].min : 0
      @latest_report = @participant.latest_report
      @recent_resources = @participant.shared_resources(limit: 3)
      @price = Setting.fetch("membership_price_clp").to_i
      @can_pay = @participant.pays_individually? && Setting.fetch("webpay_enabled") && @price.positive?

      # Day-14 upsell: a reviewed, paid personalized Nivel 2 awaiting payment.
      if @participant.nivel2_offered? && Setting.fetch("webpay_enabled")
        @nivel2_template = @participant.nivel2_template
        @nivel2_founder  = @participant.nivel2_offer_active?
        @nivel2_price    = @nivel2_template.effective_price_clp(within_founder_window: @nivel2_founder)
      end
    end
  end
end
