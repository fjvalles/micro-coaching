class CopilotPendingAction < ApplicationRecord
  belongs_to :copilot_session
  belongs_to :copilot_message, optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2, executed: 3, failed: 4 }

  validates :tool_name, presence: true

  scope :awaiting, -> { where(status: :pending) }

  # Refresh the pending-actions panel when one is created or its status changes.
  after_create_commit :broadcast_pending
  after_update_commit :broadcast_pending

  def broadcast_pending
    broadcast_replace_to(
      [ copilot_session, :pending ],
      target: "copilot_pending",
      partial: "admin/copilot/pending_actions",
      locals: { session: copilot_session }
    )
  end
end
