class ChangeItemIdInVersionsToString < ActiveRecord::Migration[7.2]
  def up
    change_column :versions, :item_id, :string
  end

  def down
    change_column :versions, :item_id, 'bigint USING item_id::bigint'
  end
end
