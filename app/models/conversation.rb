class Conversation < ApplicationRecord
  include Discard::Model

  belongs_to :participant

  enum :moment, {
    welcome: 0,
    morning_wake: 1,
    iareto: 2,
    checkin_question: 3,
    checkin_response: 4,
    free_user: 5,
    free_assistant: 6,
    manifesto: 7
  }

  enum :role, { user: 0, assistant: 1, system: 2 }

  validates :moment, presence: true
  validates :role, presence: true

  scope :kept, -> { undiscarded }
  scope :chronological, -> { order(:created_at) }
  scope :failed, -> { where.not(error_message: nil) }
  scope :for_day, ->(day) { where(day_number: day) }
end
