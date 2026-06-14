class CreatePromptTuningRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_quality_scores, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.datetime :window_start, null: false
      t.datetime :window_end, null: false
      t.integer :score, null: false
      t.integer :sample_size, null: false, default: 0
      t.jsonb :subscores, null: false, default: {}
      t.jsonb :examples, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :conversation_quality_scores, :created_at
    add_index :conversation_quality_scores, [ :window_start, :window_end ], name: "index_conversation_quality_scores_on_window"

    create_table :prompt_tuning_runs, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :conversation_quality_score, type: :uuid, foreign_key: true
      t.references :prompt_version, type: :uuid, foreign_key: true
      t.string :status, null: false, default: "observed"
      t.string :mode, null: false, default: "observe"
      t.datetime :window_start, null: false
      t.datetime :window_end, null: false
      t.integer :score, null: false
      t.integer :baseline_score
      t.integer :post_score
      t.string :change_kind
      t.text :current_guardrails
      t.text :proposed_guardrails
      t.text :previous_guardrails
      t.text :applied_guardrails
      t.jsonb :findings, null: false, default: {}
      t.jsonb :validation_errors, null: false, default: []
      t.text :rationale
      t.datetime :applied_at
      t.datetime :rejected_at
      t.datetime :rolled_back_at
      t.timestamps
    end

    add_index :prompt_tuning_runs, :status
    add_index :prompt_tuning_runs, :mode
    add_index :prompt_tuning_runs, :created_at
    add_index :prompt_tuning_runs, [ :window_start, :window_end ], name: "index_prompt_tuning_runs_on_window"
  end
end
