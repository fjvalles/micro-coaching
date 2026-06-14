class SeedOpenaiModelSettings < ActiveRecord::Migration[7.2]
  SETTINGS = {
    "openai_model_preview_challenge" => [ "gpt-5-nano", "Modelo para la demo publica de reto en la landing." ],
    "openai_model_morning_message" => [ "gpt-5-mini", "Modelo para generar el mensaje matinal personalizado." ],
    "openai_model_free_response" => [ "gpt-5-mini", "Modelo para respuestas libres al participante por WhatsApp." ],
    "openai_model_inbound_intent_classifier" => [ "gpt-5-nano", "Modelo para clasificar semanticamente mensajes entrantes." ],
    "openai_model_checkin_summarizer" => [ "gpt-5-nano", "Modelo para resumir check-ins nocturnos en JSON." ],
    "openai_model_participant_summary" => [ "gpt-5-nano", "Modelo para mantener el resumen rodante del participante." ],
    "openai_model_skill_tagger" => [ "gpt-5-nano", "Modelo para etiquetar habilidades humanas detectadas en mensajes." ],
    "openai_model_manifesto" => [ "gpt-5-mini", "Modelo para generar el manifiesto de cierre." ],
    "openai_model_pattern_clusterer" => [ "gpt-5-nano", "Modelo para agrupar patrones recurrentes en metodologia." ],
    "openai_model_prompt_critic" => [ "gpt-5-mini", "Modelo para analizar y proponer mejoras de prompts." ]
  }.freeze

  def up
    SETTINGS.each do |key, (value, description)|
      execute <<~SQL.squish
        INSERT INTO settings (id, key, value, description, value_type, category, created_at, updated_at)
        VALUES (gen_random_uuid(), #{quote(key)}, #{quote(value)}, #{quote(description)}, 'string', 'openai', NOW(), NOW())
        ON CONFLICT (key) DO NOTHING
      SQL
    end
  end

  def down
    clauses = SETTINGS.map do |key, (value, description)|
      "(key = #{quote(key)} AND value = #{quote(value)} AND description = #{quote(description)})"
    end.join(" OR ")

    execute <<~SQL.squish
      DELETE FROM settings
      WHERE value_type = 'string'
        AND category = 'openai'
        AND (#{clauses})
    SQL
  end
end
