class AddNameToAdminUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :admin_users, :name, :string
  end
end
