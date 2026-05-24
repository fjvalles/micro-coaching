class AddTypingToSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :settings, :value_type, :string, null: false, default: "string"
    add_column :settings, :category,   :string, null: false, default: "general"
    add_index  :settings, :category
  end
end
