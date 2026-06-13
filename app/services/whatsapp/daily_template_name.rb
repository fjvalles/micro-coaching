# frozen_string_literal: true

module Whatsapp
  class DailyTemplateName
    CYCLE_DAYS = 14
    STANDARD_PATTERN = /\A(?<prefix>[a-z]+)_dia_\d{2}\z/

    def self.call(prefix:, day_number:, configured_name: nil)
      configured = configured_name.to_s.presence
      return configured if configured && custom_name?(configured, prefix)

      format("%<prefix>s_dia_%<day>02d", prefix: prefix, day: cycle_day(day_number))
    end

    def self.cycle_day(day_number)
      day = day_number.to_i
      day = 1 if day < 1

      ((day - 1) % CYCLE_DAYS) + 1
    end

    def self.custom_name?(name, prefix)
      match = name.match(STANDARD_PATTERN)
      match.nil? || match[:prefix] != prefix
    end
  end
end
