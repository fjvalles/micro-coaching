# frozen_string_literal: true

class DeviseCreateAdminUsers < ActiveRecord::Migration[7.2]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :admin_users, id: :uuid do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      t.datetime :remember_created_at

      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :admin_users, :email,                unique: true
    add_index :admin_users, :reset_password_token, unique: true
    add_index :admin_users, :unlock_token,         unique: true
  end
end
