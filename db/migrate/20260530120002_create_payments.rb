class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments, id: :uuid do |t|
      t.references :participant, type: :uuid, foreign_key: true, null: true
      t.references :company,     type: :uuid, foreign_key: true, null: true
      t.references :program,     type: :uuid, foreign_key: true, null: true

      t.integer :amount,     null: false, default: 0   # gross CLP charged (IVA included)
      t.string  :currency,   null: false, default: "CLP"
      t.integer :status,     null: false, default: 0   # pending/authorized/rejected/failed/aborted/refunded

      # Webpay Plus transaction identifiers
      t.string  :buy_order,  null: false
      t.string  :session_id
      t.string  :token                                  # token_ws returned by Webpay

      # Commit result snapshot
      t.string  :authorization_code
      t.string  :payment_type_code
      t.integer :response_code
      t.integer :installments
      t.string  :card_last4
      t.string  :payer_email

      # Money snapshot at commit (CLP)
      t.integer :commission_amount, null: false, default: 0
      t.integer :net_amount,        null: false, default: 0

      t.jsonb    :raw_response, null: false, default: {}
      t.datetime :paid_at
      t.timestamps
    end

    add_index :payments, :buy_order, unique: true
    add_index :payments, :token
    add_index :payments, :status
    add_index :payments, :paid_at
  end
end
