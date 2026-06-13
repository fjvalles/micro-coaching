class PromptExecution < ApplicationRecord
  belongs_to :prompt_template
  belongs_to :prompt_version
  belongs_to :program, optional: true
  belongs_to :participant, optional: true
  belongs_to :conversation, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_day, ->(day) { where(day_number: day) }
  scope :for_moment, ->(moment) { where(moment: moment) }
end
