class CreatePrograms < ActiveRecord::Migration[7.2]
  def change
    create_table :programs, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.string  :name,       null: false
      t.string  :slug,       null: false
      t.text    :description
      t.text    :manifesto
      t.integer :total_days, null: false, default: 14
      t.boolean :active,     null: false, default: true
      t.timestamps
    end

    add_index :programs, :slug, unique: true
  end
end
