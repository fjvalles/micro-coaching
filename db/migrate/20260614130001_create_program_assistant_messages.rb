class CreateProgramAssistantMessages < ActiveRecord::Migration[7.2]
  # Append-only transcript of one program-assistant session. Every turn is a
  # row: user prompts, assistant replies, and tool-call results. Doubles as the
  # audit log of what the assistant read and proposed. Never edited after write.
  def change
    create_table :program_assistant_messages, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :program_assistant_session, null: false, type: :uuid, foreign_key: true, index: { name: "idx_pa_messages_on_session" }
      t.integer  :role,        null: false, default: 0 # user / assistant / tool / system
      t.text     :content
      t.string   :tool_name
      t.jsonb    :tool_args,   null: false, default: {}
      t.jsonb    :tool_result
      t.string   :model_used
      t.integer  :tokens_input,  null: false, default: 0
      t.integer  :tokens_output, null: false, default: 0
      t.timestamps
    end

    add_index :program_assistant_messages, [ :program_assistant_session_id, :created_at ], name: "idx_pa_messages_on_session_created"
  end
end
