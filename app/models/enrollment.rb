class Enrollment < ApplicationRecord
  belongs_to :participant
  belongs_to :program

  enum :status, { active: 0, completed: 1, canceled: 2 }

  validates :cycle_number, numericality: { only_integer: true, greater_than: 0 }
  validates :program_id, uniqueness: { scope: [ :participant_id, :cycle_number ] }

  scope :ordered, -> { order(:cycle_number) }
end
