class AddResponseModeAndPendingResponses < ActiveRecord::Migration[7.2]
  def change
    add_column :programs, :response_mode, :string
    add_column :participants, :response_mode, :string

    create_table :pending_responses, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :participant, type: :uuid, null: false, foreign_key: true, index: true
      t.references :conversation, type: :uuid, null: true, foreign_key: true, index: true
      t.references :approved_by, type: :uuid, null: true, foreign_key: { to_table: :admin_users }
      t.string :status, null: false, default: "pending"
      t.string :mode, null: false
      t.string :moment, null: false
      t.integer :day_number
      t.text :draft_body, null: false
      t.text :original_body
      t.text :prompt_used
      t.string :model_used
      t.integer :tokens_input
      t.integer :tokens_output
      t.string :template_name
      t.jsonb :template_variables, default: [], null: false
      t.string :delivery_kind, null: false, default: "text"
      t.text :rejection_reason
      t.datetime :acted_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :pending_responses, :status
    add_index :pending_responses, :discarded_at
    add_index :pending_responses, [ :participant_id, :status ]
  end
end
