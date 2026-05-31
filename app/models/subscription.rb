class Subscription < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :participant, optional: true
  belongs_to :company, optional: true
  belongs_to :program, optional: true
  has_many :payments, dependent: :nullify

  # pending   → inscription started, no token yet
  # active    → tokenized, billing on schedule
  # past_due  → a charge failed past the retry limit (needs attention)
  # canceled  → ended (token deleted / user opted out)
  # paused    → temporarily suspended (no billing)
  enum :status, { pending: 0, active: 1, past_due: 2, canceled: 3, paused: 4 }

  validates :amount_clp, numericality: { greater_than_or_equal_to: 0 }
  validates :billing_interval_days, numericality: { greater_than: 0 }

  scope :kept, -> { undiscarded }
  # Active subscriptions whose next charge is due. Drives SubscriptionBillingJob.
  scope :billable, ->(now = Time.current) { kept.active.where(next_billing_at: ..now) }

  def due_for_billing?(now = Time.current)
    active? && next_billing_at.present? && next_billing_at <= now
  end

  # Advance the billing clock after a successful charge.
  def schedule_next_cycle!(from = Time.current)
    update!(
      next_billing_at:     from + billing_interval_days.days,
      last_billed_at:      from,
      billing_cycle_count: billing_cycle_count + 1,
      failed_attempts:     0
    )
  end

  # Persists an authorized Oneclick charge as a Payment linked to this subscription,
  # snapshotting the Transbank commission. `result` is a Webpay::OneclickClient::ChargeResult.
  # Shared by the first charge (SubscriptionsController) and each cycle (SubscriptionBillingJob).
  def record_charge!(buy_order:, result:)
    payment = payments.new(
      participant:        participant,
      company:            company,
      program:            program,
      amount:             amount_clp,
      buy_order:          buy_order,
      status:             :authorized,
      authorization_code: result.authorization_code,
      payment_type_code:  result.payment_type_code,
      response_code:      result.response_code,
      installments:       result.installments,
      paid_at:            Time.current,
      raw_response:       result.raw
    )
    payment.assign_commission_snapshot!
    payment.save!
    payment
  end
end
