class CreateParticipantReminders < ActiveRecord::Migration[7.2]
  def change
    create_table :participant_reminders, id: :uuid do |t|
      t.references :participant, null: false, type: :uuid, foreign_key: true
      t.references :source_conversation, type: :uuid, foreign_key: { to_table: :conversations }, index: false
      t.references :sent_conversation, type: :uuid, foreign_key: { to_table: :conversations }, index: false
      t.string :status, null: false, default: "pending"
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.datetime :canceled_at
      t.string :timezone, null: false
      t.text :requested_text, null: false
      t.text :body, null: false
      t.string :failure_reason
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :participant_reminders, [ :participant_id, :status, :scheduled_at ]
    add_index :participant_reminders, :status
    add_index :participant_reminders, :scheduled_at
    add_index :participant_reminders, :source_conversation_id,
              unique: true,
              where: "source_conversation_id IS NOT NULL"
    add_index :participant_reminders, :sent_conversation_id
  end
end
