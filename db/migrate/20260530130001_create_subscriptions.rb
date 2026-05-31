class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :participant, type: :uuid, null: true, foreign_key: true
      t.references :company,     type: :uuid, null: true,  foreign_key: true
      t.references :program,     type: :uuid, null: true,  foreign_key: true

      t.integer :status, null: false, default: 0
      t.string  :plan
      t.integer :amount_clp, null: false, default: 0

      # Webpay Oneclick tokenization: tbk_user is the recurring token returned at
      # inscription; tbk_username is the identifier we sent. Never the card itself.
      t.string :tbk_user
      t.string :tbk_username
      t.string :card_last4

      t.integer  :billing_interval_days, null: false, default: 30
      t.datetime :next_billing_at
      t.integer  :billing_cycle_count, null: false, default: 0
      t.datetime :last_billed_at
      t.integer  :failed_attempts, null: false, default: 0

      t.datetime :started_at
      t.datetime :canceled_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, :next_billing_at
    add_index :subscriptions, :discarded_at
    add_index :subscriptions, :tbk_user
  end
end
