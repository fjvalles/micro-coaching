class CreateConversations < ActiveRecord::Migration[7.2]
  def change
    create_table :conversations, id: :uuid do |t|
      t.references :participant, type: :uuid, null: false, foreign_key: true
      t.integer :day_number
      t.integer :moment, null: false
      t.integer :role, null: false
      t.text :body
      t.string :whatsapp_message_id
      t.string :whatsapp_template_name
      t.text :prompt_used
      t.string :model_used
      t.integer :tokens_input
      t.integer :tokens_output
      t.text :error_message
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :conversations, :whatsapp_message_id, unique: true, where: "whatsapp_message_id IS NOT NULL"
    add_index :conversations, :moment
    add_index :conversations, [:participant_id, :day_number]
    add_index :conversations, :discarded_at
  end
end
