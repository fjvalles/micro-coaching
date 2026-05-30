class CreateCompanies < ActiveRecord::Migration[7.2]
  def change
    create_table :companies, id: :uuid do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.string  :coach_name           # per-company override of the global coach_name Setting
      t.string  :contact_email
      t.boolean :active, null: false, default: true
      t.boolean :covers_membership, null: false, default: true # if true, members don't pay individually
      t.text    :notes
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :companies, :slug, unique: true
    add_index :companies, :discarded_at
  end
end
