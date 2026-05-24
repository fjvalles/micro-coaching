class CreateParticipants < ActiveRecord::Migration[7.2]
  def change
    create_table :participants, id: :uuid do |t|
      t.string :name, null: false
      t.string :phone_e164, null: false
      t.string :email
      t.integer :status, null: false, default: 0
      t.integer :current_day, null: false, default: 0
      t.datetime :enrolled_at
      t.datetime :started_at
      t.datetime :completed_at
      t.string :timezone, null: false, default: "America/Santiago"
      t.text :initial_pattern
      t.jsonb :energy_map, default: {}
      t.text :closing_manifesto
      t.datetime :pending_checkin_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :participants, :phone_e164, unique: true
    add_index :participants, :status
    add_index :participants, :discarded_at
  end
end
