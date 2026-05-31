class AddSubscriptionToPayments < ActiveRecord::Migration[7.2]
  def change
    add_reference :payments, :subscription, type: :uuid, null: true, foreign_key: true
  end
end
