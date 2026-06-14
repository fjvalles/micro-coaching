module Admin
  # Day-14 conversion funnel — the riskiest assumption is "will people pay?", so
  # this is launch-day instrumentation, not a later analytics phase. Each step is a
  # raw count plus the conversion rate from the prior step.
  class FunnelController < BaseController
    def index
      completed_free = Enrollment.where(cycle_number: 1, status: :completed).distinct.count(:participant_id)
      offers_sent    = Participant.kept.where.not(nivel2_offer_sent_at: nil).count
      designed       = Participant.kept.where("intake_state ->> 'template_program_id' IS NOT NULL").count
      paid           = Payment.personalized.authorized.distinct.count(:participant_id)
      guaranteed     = Participant.kept.where.not(guarantee_claimed_at: nil).count

      @steps = [
        step("Completaron Nivel 1 (gratis)", completed_free, nil),
        step("Oferta de día 14 enviada",     offers_sent,    completed_free),
        step("Diseñaron su Nivel 2 (intake)", designed,      offers_sent),
        step("Pagaron Nivel 2",              paid,           designed),
        step("Reclamaron garantía",          guaranteed,     paid)
      ]
    end

    private

    def step(label, count, prev_count)
      rate = prev_count.to_i.positive? ? (count.to_f / prev_count * 100).round(1) : nil
      { label: label, count: count, rate: rate }
    end
  end
end
