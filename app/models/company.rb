class Company < ApplicationRecord
  include Discard::Model

  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }

  has_many :participants, dependent: :nullify
  has_many :programs, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, hyphens" }

  scope :kept,    -> { undiscarded }
  scope :active,  -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  before_validation :ensure_slug, on: :create

  # Coach name shown to this company's participants: per-company override, else global Setting.
  def resolved_coach_name
    coach_name.presence || Setting.fetch("coach_name").to_s.presence
  end

  private

  def ensure_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end
end
