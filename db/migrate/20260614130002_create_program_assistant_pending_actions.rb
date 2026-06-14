class CreateProgramAssistantPendingActions < ActiveRecord::Migration[7.2]
  # The human-in-the-loop gate. When the assistant decides to run an ACT tool
  # (create or edit a program) it does NOT execute — it writes a pending action
  # here. An admin approves or rejects it from the chat modal; only on approval
  # does the wrapped service run. Primary defense against prompt-injection
  # turning a read into a write.
  def change
    create_table :program_assistant_pending_actions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :program_assistant_session, null: false, type: :uuid, foreign_key: true, index: { name: "idx_pa_actions_on_session" }
      t.references :program_assistant_message, type: :uuid, foreign_key: true, index: { name: "idx_pa_actions_on_message" }
      t.string   :tool_name, null: false
      t.jsonb    :args,      null: false, default: {}
      t.integer  :status,    null: false, default: 0 # pending / approved / rejected / executed / failed
      t.jsonb    :result
      t.string   :approved_by
      t.datetime :executed_at
      t.timestamps
    end

    add_index :program_assistant_pending_actions, [ :program_assistant_session_id, :status ], name: "idx_pa_actions_on_session_status"
  end
end
