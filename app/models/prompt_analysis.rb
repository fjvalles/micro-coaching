class PromptAnalysis < ApplicationRecord
  belongs_to :prompt_template
  belongs_to :prompt_version, optional: true

  scope :recent, -> { order(created_at: :desc) }
end
