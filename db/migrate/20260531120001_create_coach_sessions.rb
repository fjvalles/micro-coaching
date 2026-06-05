class CreateCoachSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :coach_sessions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :participant, type: :uuid, null: false, foreign_key: true
      t.references :admin_user,  type: :uuid, null: true,  foreign_key: true # coach

      t.integer  :status, null: false, default: 0
      t.datetime :scheduled_at
      t.integer  :duration_minutes, null: false, default: 30
      t.string   :meeting_url
      t.text     :notes
      t.datetime :reminder_sent_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :coach_sessions, :status
    add_index :coach_sessions, :scheduled_at
    add_index :coach_sessions, :discarded_at
  end
end
