class Setting < ApplicationRecord
  VALUE_TYPES  = %w[string text integer float boolean json].freeze
  CATEGORIES   = %w[timing openai whatsapp program admin general].freeze
  CACHE_PREFIX = "setting:".freeze
  CACHE_TTL    = 5.minutes

  # Canonical schema. Add entries here; consumers read via Setting.fetch(key).
  # Each entry: type, category, description, default, optional validate proc.
  SCHEMA = {
    # ── timing ─────────────────────────────────────────────────────────────
    "wake_hour" => {
      type: :integer, category: "timing", default: 7,
      description: "Hora local (0–23) en que se dispara el mensaje matinal.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "checkin_hour" => {
      type: :integer, category: "timing", default: 20,
      description: "Hora local (0–23) en que se dispara el check-in nocturno.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "iareto_delay_minutes" => {
      type: :integer, category: "timing", default: 30,
      description: "Minutos entre el mensaje matinal y el envío del Iareto.",
      validate: ->(v) { (0..240).cover?(v) || "debe estar entre 0 y 240" }
    },
    "welcome_question_delay_minutes" => {
      type: :integer, category: "timing", default: 2,
      description: "Minutos entre la bienvenida y la pregunta de patrón inicial.",
      validate: ->(v) { (0..1440).cover?(v) || "debe estar entre 0 y 1440" }
    },
    "inactivity_pause_days" => {
      type: :integer, category: "timing", default: 5,
      description: "Días sin respuesta antes de pausar al participante. (Scaffolded, no aplicado todavía.)",
      validate: ->(v) { (1..30).cover?(v) || "debe estar entre 1 y 30" }
    },
    "default_timezone" => {
      type: :string, category: "timing", default: "America/Mexico_City",
      description: "Zona horaria fallback cuando el participante no tiene una asignada.",
      validate: ->(v) { ActiveSupport::TimeZone[v].present? || "zona horaria inválida" }
    },

    # ── openai ─────────────────────────────────────────────────────────────
    "openai_model" => {
      type: :string, category: "openai", default: "gpt-4.1-mini",
      description: "Modelo de OpenAI usado en todas las llamadas generativas."
    },
    "openai_temperature_generative" => {
      type: :float, category: "openai", default: 0.75,
      description: "Temperatura para llamadas generativas (matinal, libre, manifiesto).",
      validate: ->(v) { (0.0..2.0).cover?(v) || "debe estar entre 0.0 y 2.0" }
    },
    "openai_temperature_json" => {
      type: :float, category: "openai", default: 0.3,
      description: "Temperatura para llamadas de modo JSON (resumen de check-in).",
      validate: ->(v) { (0.0..2.0).cover?(v) || "debe estar entre 0.0 y 2.0" }
    },
    "openai_max_tokens_morning" => {
      type: :integer, category: "openai", default: 400,
      description: "max_tokens del mensaje matinal."
    },
    "openai_max_tokens_free" => {
      type: :integer, category: "openai", default: 400,
      description: "max_tokens de la respuesta libre."
    },
    "openai_max_tokens_checkin" => {
      type: :integer, category: "openai", default: 300,
      description: "max_tokens del resumen de check-in nocturno."
    },
    "openai_max_tokens_manifesto" => {
      type: :integer, category: "openai", default: 600,
      description: "max_tokens del manifiesto de cierre del día 15."
    },
    "openai_retry_max" => {
      type: :integer, category: "openai", default: 3,
      description: "Intentos máximos ante errores 429/5xx/timeouts de OpenAI.",
      validate: ->(v) { (1..10).cover?(v) || "debe estar entre 1 y 10" }
    },
    "openai_dry_run_global" => {
      type: :boolean, category: "openai", default: false,
      description: "Kill-switch: si es true, ningún servicio llama a OpenAI (devuelve stub)."
    },
    "max_free_messages_per_day" => {
      type: :integer, category: "openai", default: 20,
      description: "Tope de mensajes libres por participante por día. (Scaffolded, no aplicado todavía.)"
    },

    # ── whatsapp ───────────────────────────────────────────────────────────
    "whatsapp_send_enabled" => {
      type: :boolean, category: "whatsapp", default: true,
      description: "Kill-switch: si es false, Whatsapp::Client no envía nada (modo mantenimiento)."
    },
    "whatsapp_retry_max" => {
      type: :integer, category: "whatsapp", default: 3,
      description: "Intentos máximos ante 429/5xx de Meta Cloud API.",
      validate: ->(v) { (1..10).cover?(v) || "debe estar entre 1 y 10" }
    },
    "meta_api_version" => {
      type: :string, category: "whatsapp", default: "v25.0",
      description: "Versión de Meta Graph API usada en envíos (override de la env var)."
    },
    "voice_message_reply_text" => {
      type: :text, category: "whatsapp",
      default: "Por ahora solo puedo procesar texto, por favor escribe tu respuesta.",
      description: "Texto que se envía cuando llega un mensaje no-texto (imagen, video, documento) y el procesamiento de audio está desactivado."
    },
    "audio_processing_enabled" => {
      type: :boolean, category: "whatsapp", default: true,
      description: "Si es true, los mensajes de audio/voz se descargan, transcriben y analizan. Si es false, se responde con voice_message_reply_text."
    },
    "audio_max_duration_seconds" => {
      type: :integer, category: "whatsapp", default: 180,
      description: "Duración máxima (segundos) de un audio aceptado. Audios más largos reciben voice_message_reply_text.",
      validate: ->(v) { (10..600).cover?(v) || "debe estar entre 10 y 600" }
    },
    "openai_transcription_model" => {
      type: :string, category: "openai", default: "gpt-4o-mini-transcribe",
      description: "Modelo de OpenAI usado para transcribir audios entrantes (whisper-1, gpt-4o-mini-transcribe, gpt-4o-transcribe)."
    },
    "openai_voice_analysis_model" => {
      type: :string, category: "openai", default: "gpt-4o-mini-audio-preview",
      description: "Modelo multimodal de audio usado para inferir tono/emoción/ritmo a partir del audio (gpt-4o-audio-preview, gpt-4o-mini-audio-preview)."
    },
    "openai_voice_analysis_enabled" => {
      type: :boolean, category: "openai", default: true,
      description: "Kill-switch del análisis paralingüístico (tono/emoción). Si es false, solo se transcribe."
    },

    # ── program ────────────────────────────────────────────────────────────
    "program_manifesto" => {
      type: :text, category: "program",
      default: <<~TEXT,
        Eres parte de Piloto Automático: un programa de 14 días que acompaña a la persona a
        salir del modo reactivo a través de tres fases — VER (días 1–4), ELEGIR (días 5–10) y
        ANCLAR (días 11–14). Principios:

        1. No enseñar, sino activar. No das consejos no pedidos.
        2. La persona descubre, tú reflejas. Usa preguntas más que respuestas.
        3. Brevedad. Máximo 4 frases. Sin emojis. Español neutro.
        4. Tono: cálido, lúcido, sin paternalismo. Sin coaching grandilocuente.
        5. Honra lo pequeño. Una micro-elección vale más que un gran propósito.
        6. Refleja lo que la persona ya dijo antes de añadir nada nuevo.

        Tu salida llega por WhatsApp, así que evita listas largas y formato markdown.
      TEXT
      description: "System prompt global prepended a todas las llamadas OpenAI (fallback si Program#manifesto está vacío)."
    }
  }.freeze

  validates :key,        presence: true, uniqueness: true
  validates :value_type, inclusion: { in: VALUE_TYPES }
  validates :category,   inclusion: { in: CATEGORIES }
  validate  :value_passes_schema_validation

  after_commit :clear_cache

  # Typed read. Reads cache → DB → schema default.
  def self.fetch(key)
    key = key.to_s
    Rails.cache.fetch("#{CACHE_PREFIX}#{key}", expires_in: CACHE_TTL) do
      record = find_by(key: key)
      if record
        cast(record.value, record.value_type)
      elsif (schema = SCHEMA[key])
        schema[:default]
      end
    end
  end

  # Legacy string-only accessor. Prefer .fetch for new code.
  def self.get(key)
    value = fetch(key)
    value.nil? ? nil : value.to_s
  end

  def self.set(key, value)
    schema = SCHEMA[key.to_s] || {}
    record = find_or_initialize_by(key: key.to_s)
    record.value_type    = (schema[:type] || :string).to_s
    record.category      = schema[:category] || "general"
    record.description ||= schema[:description]
    record.value = serialize(value, record.value_type)
    record.save!
    record
  end

  # Idempotent. Seeds any SCHEMA entry not yet persisted.
  def self.seed_defaults!
    SCHEMA.each do |key, spec|
      next if exists?(key: key)
      create!(
        key:         key,
        value:       serialize(spec[:default], spec[:type].to_s),
        value_type:  spec[:type].to_s,
        category:    spec[:category],
        description: spec[:description]
      )
    end
  end

  def self.cast(raw, type)
    return nil if raw.nil?
    case type.to_s
    when "integer" then raw.to_i
    when "float"   then raw.to_f
    when "boolean" then ActiveModel::Type::Boolean.new.cast(raw)
    when "json"    then JSON.parse(raw) rescue nil
    else                raw.to_s
    end
  end

  def self.serialize(value, type)
    return nil if value.nil?
    case type.to_s
    when "json" then value.is_a?(String) ? value : value.to_json
    else             value.to_s
    end
  end

  def typed_value
    self.class.cast(value, value_type)
  end

  def schema_entry
    SCHEMA[key]
  end

  private

  def value_passes_schema_validation
    entry = SCHEMA[key]
    return unless entry && entry[:validate]
    casted = self.class.cast(value, value_type)
    result = entry[:validate].call(casted)
    errors.add(:value, result) if result.is_a?(String)
  end

  def clear_cache
    Rails.cache.delete("#{CACHE_PREFIX}#{key}")
  end
end
