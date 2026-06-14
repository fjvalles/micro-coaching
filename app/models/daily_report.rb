class DailyReport < ApplicationRecord
  belongs_to :participant

  validates :day_number, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  scope :chronological, -> { order(:reported_at) }
end
