class Skill < ApplicationRecord
  # List-valued sections parsed from the source content, stored as jsonb arrays.
  LIST_FIELDS = %w[signals practices gestures exercises reflection_questions].freeze

  has_many :skill_detections, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  # Detection frequency across all participants (for the admin catalog).
  def self.with_detection_counts
    left_joins(:skill_detections)
      .group(:id)
      .select("skills.*, COUNT(skill_detections.id) AS detections_count")
  end
end
