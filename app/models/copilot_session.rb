class CopilotSession < ApplicationRecord
  belongs_to :admin_user
  has_many :copilot_messages, -> { order(:created_at) }, dependent: :destroy
  has_many :copilot_pending_actions, dependent: :destroy

  enum :status, { active: 0, archived: 1 }

  validates :admin_user, presence: true

  # Token budget guard — the agent loop checks this before each OpenAI call.
  def over_token_budget?
    (tokens_input + tokens_output) >= Setting.fetch("copilot_token_budget_per_session")
  end

  # Action cap guard — counts every act tool the agent has proposed this session.
  def action_cap_reached?
    copilot_pending_actions.count >= Setting.fetch("copilot_action_cap_per_session")
  end
end
