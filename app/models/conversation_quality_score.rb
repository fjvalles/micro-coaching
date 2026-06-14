class ConversationQualityScore < ApplicationRecord
  has_many :prompt_tuning_runs, dependent: :nullify

  validates :window_start, :window_end, presence: true
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :sample_size, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }
end
