class Program < ApplicationRecord
  has_paper_trail meta: { source: proc { PaperTrail.request.controller_info.to_h[:source] } }
  has_many :day_contents, dependent: :destroy
  has_many :participants, dependent: :nullify
  has_many :prompt_templates, dependent: :destroy
  has_many :methodology_insights, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, hyphens" }
  validates :total_days, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def self.default
    active.order(:created_at).first
  end
end
