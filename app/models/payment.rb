class Payment < ApplicationRecord
  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  belongs_to :participant, optional: true
  belongs_to :company, optional: true
  belongs_to :program, optional: true
  belongs_to :subscription, optional: true

  # pending  → created, redirected to Webpay
  # authorized → committed OK
  # rejected → bank rejected
  # failed   → exception / commit error
  # aborted  → user abandoned the Webpay form (TBK_TOKEN)
  # refunded → reversed
  enum :status, { pending: 0, authorized: 1, rejected: 2, failed: 3, aborted: 4, refunded: 5 }

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :buy_order, presence: true, uniqueness: true

  scope :in_period, ->(range) { where(created_at: range) }
  scope :income,    -> { authorized }

  def self.next_buy_order
    "IMP-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  # IVA débito contenido en el monto bruto (precios chilenos son IVA-incluido).
  def tax_amount(rate = Setting.fetch("tax_rate").to_f)
    return 0 if amount.to_i.zero? || rate <= 0

    (amount - (amount / (1 + rate))).round
  end

  # Neto de venta (sin IVA).
  def net_of_tax(rate = Setting.fetch("tax_rate").to_f)
    amount.to_i - tax_amount(rate)
  end

  # Snapshot de la comisión Transbank (con su IVA) y el neto recibido. Se llama
  # al confirmar (commit) para congelar los montos con las tasas vigentes.
  def assign_commission_snapshot!
    rate = Setting.fetch("payment_commission_rate").to_f
    iva  = Setting.fetch("tax_rate").to_f
    commission           = (amount * rate).round
    commission_with_iva  = (commission * (1 + iva)).round
    self.commission_amount = commission_with_iva
    self.net_amount        = amount - commission_with_iva
  end
end
