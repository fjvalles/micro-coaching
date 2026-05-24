class PromptVersion < ApplicationRecord
  belongs_to :prompt_template
  belongs_to :author, class_name: "AdminUser", optional: true
  has_many :prompt_executions, dependent: :nullify

  validates :version, presence: true, uniqueness: { scope: :prompt_template_id }
  validates :body, presence: true

  scope :chronological, -> { order(:version) }
end
