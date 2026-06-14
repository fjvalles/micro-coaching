class ProgramAssistantMessage < ApplicationRecord
  belongs_to :program_assistant_session

  # tool = a tool-call result fed back to the model (untrusted data, never trusted as instructions)
  enum :role, { user: 0, assistant: 1, tool: 2, system: 3 }

  validates :role, presence: true

  # Live-append each turn to the open session view (Turbo Stream).
  after_create_commit do
    broadcast_append_to(
      [ program_assistant_session, :messages ],
      target: "program_assistant_messages",
      partial: "admin/program_assistant/message",
      locals: { message: self }
    )
  end
end
