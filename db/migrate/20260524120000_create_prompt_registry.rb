class CreatePromptRegistry < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_templates, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false
      t.references :program, type: :uuid, null: true, foreign_key: true
      t.integer :day_number
      t.string :name, null: false
      t.text :description
      t.text :current_body, null: false, default: ""
      t.integer :current_version, null: false, default: 0
      t.string :source, null: false, default: "service"
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :prompt_templates, [ :key, :program_id, :day_number ], unique: true, name: "idx_prompt_templates_unique"
    add_index :prompt_templates, :discarded_at

    create_table :prompt_versions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :prompt_template, type: :uuid, null: false, foreign_key: true, index: true
      t.references :author, type: :uuid, null: true, foreign_key: { to_table: :admin_users }
      t.integer :version, null: false
      t.text :body, null: false
      t.text :change_note
      t.string :origin, null: false, default: "service"
      t.timestamps
    end

    add_index :prompt_versions, [ :prompt_template_id, :version ], unique: true

    create_table :prompt_executions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :prompt_template, type: :uuid, null: false, foreign_key: true, index: true
      t.references :prompt_version, type: :uuid, null: false, foreign_key: true, index: true
      t.references :participant, type: :uuid, null: true, foreign_key: true
      t.references :conversation, type: :uuid, null: true, foreign_key: true
      t.integer :day_number
      t.string :moment
      t.jsonb :rendered_messages, default: [], null: false
      t.text :output_body
      t.string :model_used
      t.integer :tokens_input
      t.integer :tokens_output
      t.integer :latency_ms
      t.text :error_message
      t.timestamps
    end

    add_index :prompt_executions, [ :prompt_template_id, :day_number ]
    add_index :prompt_executions, :created_at

    create_table :prompt_analyses, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :prompt_template, type: :uuid, null: false, foreign_key: true, index: true
      t.references :prompt_version, type: :uuid, null: true, foreign_key: true
      t.integer :executions_sampled, null: false, default: 0
      t.jsonb :findings, default: {}, null: false
      t.text :suggested_body
      t.text :rationale
      t.string :model_used
      t.integer :tokens_input
      t.integer :tokens_output
      t.timestamps
    end

    add_index :prompt_analyses, :created_at
  end
end
