module Portal
  class DashboardController < BaseController
    def show
      @participant = current_participant
      @total_days  = @participant.program&.total_days || 14
      @reports     = @participant.daily_reports.order(reported_at: :desc)
      @price       = Setting.fetch("membership_price_clp").to_i
      @can_pay     = @participant.pays_individually? && Setting.fetch("webpay_enabled") && @price.positive?
    end
  end
end
