class CreateCopilotMessages < ActiveRecord::Migration[7.2]
  # Append-only transcript of one copilot session. Every turn is a row:
  # user prompts, assistant replies, and tool-call results. Doubles as the
  # audit log for what the copilot read and proposed. Never edited after write.
  def change
    create_table :copilot_messages, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :copilot_session, null: false, type: :uuid, foreign_key: true
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

    add_index :copilot_messages, [ :copilot_session_id, :created_at ]
  end
end
