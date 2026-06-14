class ProgramAssistantPendingAction < ApplicationRecord
  belongs_to :program_assistant_session
  belongs_to :program_assistant_message, optional: true

  enum :status, { pending: 0, approved: 1, rejected: 2, executed: 3, failed: 4 }

  validates :tool_name, presence: true

  scope :awaiting, -> { where(status: :pending) }

  # Refresh the pending-actions panel when one is created or its status changes.
  after_create_commit :broadcast_pending
  after_update_commit :broadcast_pending

  def broadcast_pending
    broadcast_replace_to(
      [ program_assistant_session, :pending ],
      target: "program_assistant_pending",
      partial: "admin/program_assistant/pending_actions",
      locals: { session: program_assistant_session }
    )
  end
end
