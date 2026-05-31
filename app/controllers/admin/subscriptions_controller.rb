module Admin
  # Read-only visibility into recurring subscriptions: status mix, active count and
  # monthly recurring revenue (CLP). Charges themselves show up under Ingresos as
  # Payments linked to each subscription.
  class SubscriptionsController < BaseController
    def index
      scope = Subscription.kept

      @by_status    = scope.group(:status).count
      @active_count = scope.active.count
      @mrr          = scope.active.sum(:amount_clp) # CLP, IVA incl.
      @subscriptions = scope.includes(:participant).order(created_at: :desc).limit(100)
    end
  end
end
