class CreateSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :settings, id: :uuid do |t|
      t.string :key, null: false
      t.text :value
      t.text :description

      t.timestamps
    end
    add_index :settings, :key, unique: true
  end
end
