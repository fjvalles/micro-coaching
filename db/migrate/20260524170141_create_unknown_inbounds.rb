class CreateUnknownInbounds < ActiveRecord::Migration[7.2]
  def change
    create_table :unknown_inbounds, id: :uuid do |t|
      t.string :phone
      t.string :wamid
      t.string :message_type
      t.string :body_preview
      t.datetime :received_at

      t.timestamps
    end
  end
end
