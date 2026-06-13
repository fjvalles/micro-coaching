class AddInboundIntentToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :inbound_intent, :string
    add_column :conversations, :inbound_intent_confidence, :decimal, precision: 4, scale: 3
    add_column :conversations, :inbound_intent_reason, :text

    add_index :conversations, :inbound_intent
  end
end
