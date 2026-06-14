class Program < ApplicationRecord
  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }
  belongs_to :company, optional: true # nil = general program (available to everyone)
  # Self-referential chain for multi-cycle journeys (Nivel 1 → Nivel 2).
  belongs_to :next_program, class_name: "Program", optional: true
  has_many :day_contents, dependent: :destroy
  has_many :participants, dependent: :nullify
  has_many :enrollments, dependent: :destroy
  has_many :prompt_templates, dependent: :destroy
  has_many :methodology_insights, dependent: :destroy
  has_many :resources, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, hyphens" }
  validates :total_days, numericality: { only_integer: true, greater_than: 0 }

  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :general, -> { where(company_id: nil) }
  scope :for_company, ->(company) { where(company_id: company) }
  scope :templates, -> { where(template: true) }
  scope :live, -> { where(template: false) }

  # Programs a participant may be enrolled in: general programs plus any owned by
  # the participant's company. Generated templates (reviewable artifacts) are never
  # directly enrollable, even if a template is toggled active.
  scope :available_to, ->(company) {
    base = company ? where(company_id: [ nil, company.try(:id) || company ]) : general
    base.live
  }

  def general?
    company_id.nil?
  end

  # A program that costs money to enroll in (paid Nivel 2). price_clp == 0 is the
  # free Nivel 1 trial.
  def paid?
    price_clp.to_i.positive?
  end

  # Single source of truth for "what does the participant pay right now". Inside the
  # day-14 founder window (Participant#nivel2_offer_active?) the discounted
  # founder_price_clp applies, when set; otherwise the standing price_clp.
  def effective_price_clp(within_founder_window:)
    return founder_price_clp if within_founder_window && founder_price_clp.to_i.positive?

    price_clp
  end

  # Never returns a template — a template toggled active must not become the default.
  def self.default
    general.live.active.order(:created_at).first || live.active.order(:created_at).first
  end
end
