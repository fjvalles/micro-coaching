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
  # the participant's company.
  scope :available_to, ->(company) {
    company ? where(company_id: [ nil, company.try(:id) || company ]) : general
  }

  def general?
    company_id.nil?
  end

  def self.default
    general.active.order(:created_at).first || active.order(:created_at).first
  end
end
