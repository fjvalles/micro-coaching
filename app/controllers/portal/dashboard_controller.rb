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
    end
  end
end
