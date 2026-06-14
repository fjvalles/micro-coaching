class CreateResourcesAndResourceDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_table :resources, id: :uuid do |t|
      t.string :title, null: false
      t.text :url, null: false
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :source, null: false, default: "manual"
      t.text :description
      t.jsonb :topics, null: false, default: []
      t.references :program, type: :uuid, foreign_key: true
      t.datetime :last_verified_at
      t.jsonb :verification, null: false, default: {}
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :resources, :status
    add_index :resources, :kind
    add_index :resources, :source
    add_index :resources, :discarded_at
    add_index :resources, "lower(url)", unique: true, name: "index_resources_on_lower_url"
    add_index :resources, :topics, using: :gin

    create_table :resource_deliveries, id: :uuid do |t|
      t.references :resource, type: :uuid, null: false, foreign_key: true
      t.references :participant, type: :uuid, null: false, foreign_key: true
      t.references :conversation, type: :uuid, foreign_key: true
      t.string :moment
      t.timestamps
    end

    add_index :resource_deliveries, [ :participant_id, :resource_id ]
  end
end
