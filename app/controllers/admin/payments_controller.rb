module Admin
  class PaymentsController < BaseController
    include PeriodFilterable

    def index
      @period = params[:period] || "this_month"
      @range  = period_range(@period)
      @period_label = period_label(@period)

      scope      = Payment.in_period(@range)
      authorized = scope.authorized
      tax_rate   = Setting.fetch("tax_rate").to_f

      @count        = authorized.count
      @gross        = authorized.sum(:amount)
      @iva          = authorized.sum { |p| p.tax_amount(tax_rate) }
      @neto         = @gross - @iva
      @commission   = authorized.sum(:commission_amount)
      @net_received = authorized.sum(:net_amount)
      @by_status    = scope.group(:status).count

      @payments = scope.includes(:participant, :company).order(created_at: :desc).limit(100)
    end

    def show
      @payment = Payment.find(params[:id])
    end
  end
end
