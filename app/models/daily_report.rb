class DailyReport < ApplicationRecord
  belongs_to :participant

  validates :day_number, presence: true,
            numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 14 }

  scope :chronological, -> { order(:reported_at) }
end
