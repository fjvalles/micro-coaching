module ParticipantReminders
  class Parser
    Result = Struct.new(:reminder, :scheduled_at, :reason, :metadata, keyword_init: true) do
      def reminder? = reminder
    end

    REMINDER_RE = /\b(avisame|recuerdame|recordame|notificame|mandame un recordatorio|mandame mensaje|me recuerdas)\b/
    UNSUPPORTED_CONTENT_RE = /\b(medicamento|pastilla|remedio|insulina|presion|doctor|medico|urgencia|pagar|cuenta|banco|transferencia|impuesto|legal|abogado|llamar a|escribirle a)\b/
    PROGRAM_CONTENT_RE = /\b(reto|programa|coaching|paso|tarea|gesto|hoy|esto|hacerlo|retomar|continuar|check-?in|iareto)\b/

    def initialize(text:, participant:, now: Time.current)
      @text = text.to_s
      @participant = participant
      @now = now
    end

    def call
      normalized = normalize(@text)
      return Result.new(reminder: false, reason: "missing reminder keyword") unless normalized.match?(REMINDER_RE)
      return Result.new(reminder: false, reason: "unsupported reminder content") unless allowed_content?(normalized)

      scheduled_at = parse_relative(normalized) || parse_absolute(normalized)
      return Result.new(reminder: true, reason: "missing time reference") unless scheduled_at

      Result.new(
        reminder: true,
        scheduled_at: scheduled_at,
        reason: "parsed reminder request",
        metadata: { parser: "deterministic", normalized_text: normalized.truncate(500) }
      )
    end

    private

    def parse_relative(normalized)
      match = normalized.match(/\ben\s+(\d{1,3})\s+(minuto|minutos|hora|horas|dia|dias)\b/)
      return unless match

      amount = match[1].to_i
      unit = match[2]
      case unit
      when "minuto", "minutos" then @now + amount.minutes
      when "hora", "horas"     then @now + amount.hours
      when "dia", "dias"       then @now + amount.days
      end
    end

    def parse_absolute(normalized)
      time = parse_clock_time(normalized)
      return unless time

      date = if normalized.match?(/\bmanana\b/)
               local_now.to_date + 1.day
      elsif normalized.match?(/\bhoy\b/)
               local_now.to_date
      else
               local_now.to_date
      end

      local = zone.local(date.year, date.month, date.day, time[:hour], time[:minute])
      local += 1.day if local <= local_now && !normalized.match?(/\b(hoy|manana)\b/)
      local
    end

    def parse_clock_time(normalized)
      match = normalized.match(/\b(?:a\s+las|a\s+la|alas|para\s+las|tipo)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b/)
      return unless match

      hour = match[1].to_i
      minute = (match[2] || "0").to_i
      suffix = match[3].to_s.delete(".")

      period = suffix.presence
      period ||= "pm" if normalized.match?(/\b(tarde|noche)\b/)
      period ||= "am" if normalized.match?(/\b(manana)\b/) && !normalized.match?(/\bmanana\s+a\s+las\b/)

      hour = normalize_hour(hour, period)
      return unless (0..23).cover?(hour) && (0..59).cover?(minute)

      { hour: hour, minute: minute }
    end

    def normalize_hour(hour, period)
      return hour if period.blank?

      if period == "pm"
        hour == 12 ? 12 : hour + 12
      elsif period == "am"
        hour == 12 ? 0 : hour
      else
        hour
      end
    end

    def allowed_content?(normalized)
      return false if normalized.match?(UNSUPPORTED_CONTENT_RE)

      content = normalized.sub(REMINDER_RE, "").strip
      content_without_time = content
                             .gsub(/\b(si|sí|ok|okay|dale|listo|perfecto|entendido|de acuerdo)\b/, "")
                             .gsub(/\b(?:hoy|manana)\b/, "")
                             .gsub(/\b(?:a\s+las|a\s+la|alas|para\s+las|tipo)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|a\.m\.|p\.m\.)?\b/, "")
                             .gsub(/\ben\s+\d{1,3}\s+(?:minuto|minutos|hora|horas|dia|dias)\b/, "")
                             .gsub(/[[:punct:]]/, "")
                             .strip

      content_without_time.blank? || normalized.match?(PROGRAM_CONTENT_RE)
    end

    def normalize(text)
      I18n.transliterate(text.downcase).squish
    end

    def zone
      @zone ||= ActiveSupport::TimeZone[@participant.timezone] || Time.zone
    end

    def local_now
      @local_now ||= @now.in_time_zone(zone)
    end
  end
end
