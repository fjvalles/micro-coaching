class SkillDetection < ApplicationRecord
  belongs_to :participant
  belongs_to :conversation
  belongs_to :skill

  validates :detected_at, presence: true

  scope :recent, -> { order(detected_at: :desc) }
  scope :since, ->(time) { where("detected_at >= ?", time) }
end
