class CreateCopilotPendingActions < ActiveRecord::Migration[7.2]
  # The human-in-the-loop gate. When the copilot decides to run an ACT tool
  # (send a message, pause a participant, etc.) it does NOT execute — it writes
  # a pending action here. A superadmin approves or rejects it from the chat UI;
  # only on approval does the wrapped service run. This is the primary defense
  # against prompt-injection turning a read into an outbound action.
  def change
    create_table :copilot_pending_actions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :copilot_session, null: false, type: :uuid, foreign_key: true
      t.references :copilot_message, type: :uuid, foreign_key: true # the assistant turn that proposed it
      t.string   :tool_name, null: false
      t.jsonb    :args,      null: false, default: {}
      t.integer  :status,    null: false, default: 0 # pending / approved / rejected / executed / failed
      t.jsonb    :result
      t.string   :approved_by
      t.datetime :executed_at
      t.timestamps
    end

    add_index :copilot_pending_actions, [ :copilot_session_id, :status ]
  end
end
