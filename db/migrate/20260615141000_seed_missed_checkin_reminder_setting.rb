class SeedMissedCheckinReminderSetting < ActiveRecord::Migration[7.2]
  KEY = "missed_checkin_reminder_text"
  VALUE = "Antes de abrir el siguiente paso, cerremos el check-in pendiente. Responde las preguntas del día cuando puedas; con eso retomamos el avance."
  DESCRIPTION = "Mensaje matinal cuando el participante tiene pendiente el check-in de un día anterior; bloquea la cadencia normal hasta responder."

  def up
    execute <<~SQL.squish
      INSERT INTO settings (id, key, value, description, value_type, category, created_at, updated_at)
      VALUES (gen_random_uuid(), #{quote(KEY)}, #{quote(VALUE)}, #{quote(DESCRIPTION)}, 'text', 'program', NOW(), NOW())
      ON CONFLICT (key) DO NOTHING
    SQL
  end

  def down
    execute <<~SQL.squish
      DELETE FROM settings
      WHERE key = #{quote(KEY)}
        AND value = #{quote(VALUE)}
        AND description = #{quote(DESCRIPTION)}
        AND value_type = 'text'
        AND category = 'program'
    SQL
  end
end
