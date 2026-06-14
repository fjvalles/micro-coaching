module Admin
  class PaymentsController < BaseController
    include PeriodFilterable

    def show
      @payment = Payment.find(params[:id])
    end
  end
end
