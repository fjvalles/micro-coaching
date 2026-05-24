class CreateDailyReports < ActiveRecord::Migration[7.2]
  def change
    create_table :daily_reports, id: :uuid do |t|
      t.references :participant, type: :uuid, null: false, foreign_key: true
      t.integer :day_number, null: false
      t.text :raw_text
      t.text :ai_summary
      t.text :ai_key_pattern
      t.datetime :reported_at
      t.timestamps
    end

    add_index :daily_reports, [:participant_id, :day_number]
  end
end
