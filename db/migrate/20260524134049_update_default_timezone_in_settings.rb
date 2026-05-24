class UpdateDefaultTimezoneInSettings < ActiveRecord::Migration[7.2]
  def up
    execute("UPDATE settings SET value = 'America/Santiago' WHERE key = 'default_timezone' AND value = 'America/Mexico_City'")
  end

  def down
    execute("UPDATE settings SET value = 'America/Mexico_City' WHERE key = 'default_timezone' AND value = 'America/Santiago'")
  end
end
