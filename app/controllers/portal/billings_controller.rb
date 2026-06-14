module Portal
  # Pagos y suscripción del participante: estado de la suscripción recurrente,
  # próximo cobro, historial de pagos y el CTA de pago para quienes pagan individual.
  class BillingsController < BaseController
    def show
      @subscriptions = Subscription.kept
                                   .where(participant: current_participant)
                                   .order(created_at: :desc)
      @payments = Payment.where(participant: current_participant)
                         .order(created_at: :desc)

      @price = Setting.fetch("membership_price_clp").to_i
      @can_pay = current_participant.pays_individually? &&
                 Setting.fetch("webpay_enabled") && @price.positive?
    end
  end
end
