class CreateMethodologyInsights < ActiveRecord::Migration[7.2]
  def change
    create_table :methodology_insights, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string   :scope, null: false
      t.jsonb    :payload, null: false, default: {}
      t.datetime :generated_at, null: false
      t.uuid     :program_id
      t.date     :window_start
      t.date     :window_end
      t.timestamps
    end

    add_index :methodology_insights, [ :scope, :generated_at ], order: { generated_at: :desc }
    add_index :methodology_insights, [ :program_id, :scope ]
    add_foreign_key :methodology_insights, :programs
  end
end
