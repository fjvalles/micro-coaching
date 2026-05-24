class AddIndexesToUnknownInbounds < ActiveRecord::Migration[7.2]
  def change
    add_index :unknown_inbounds, :wamid, unique: true
    add_index :unknown_inbounds, :received_at
  end
end
