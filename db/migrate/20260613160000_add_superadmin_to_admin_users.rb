class AddSuperadminToAdminUsers < ActiveRecord::Migration[7.2]
  # Gates the ops copilot (/admin/copilot). The copilot can read the DB and run
  # gated business actions, so it sits behind a stricter flag than the regular
  # admin namespace. Default false — grant explicitly (console or admin_users UI).
  def change
    add_column :admin_users, :superadmin, :boolean, null: false, default: false
  end
end
