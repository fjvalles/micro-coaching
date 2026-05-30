# Error tracking + alerting. Inert unless SENTRY_DSN is set, so local/dev/test boots
# and CI are unaffected. Notifications (email/Slack) are configured in the Sentry
# project itself (Alerts → "issue is first seen" / "event frequency").
#
# PRIVACY: Impulso stores PII (WhatsApp phone numbers, message bodies, transcriptions)
# governed by Chile's Ley 19.628. We never ship that to a third party. send_default_pii
# is OFF and before_send deep-scrubs phone/email/known-sensitive keys from every event.
if ENV["SENTRY_DSN"].present?
  # Recursive scrubber applied to every outgoing event hash.
  module ImpulsoSentryScrub
    PHONE = /\+?\d[\d\s\-().]{7,16}\d/
    EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/
    SENSITIVE_KEYS = %w[
      phone phone_e164 body raw_text transcription initial_pattern closing_manifesto
      email draft_body original_body text password token access_token authorization
    ].freeze

    def self.call(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), acc|
          acc[k] = SENSITIVE_KEYS.include?(k.to_s.downcase) ? "[redacted]" : call(v)
        end
      when Array
        obj.map { |e| call(e) }
      when String
        obj.gsub(EMAIL, "[email]").gsub(PHONE, "[phone]")
      else
        obj
      end
    end
  end

  Sentry.init do |config|
    config.dsn         = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.release     = ENV["KAMAL_VERSION"].presence || ENV["GIT_SHA"].presence

    config.send_default_pii   = false
    config.breadcrumbs_logger = [ :sentry_logger, :http_logger ]

    # 100% of errors; a slice of performance traces (override via env).
    config.traces_sample_rate = (ENV["SENTRY_TRACES_SAMPLE_RATE"].presence || "0.1").to_f

    # Non-actionable noise we don't want paging us.
    config.excluded_exceptions += %w[
      ActiveRecord::RecordNotFound
      ActionController::RoutingError
      ActionController::InvalidAuthenticityToken
    ]

    config.before_send = lambda do |event, _hint|
      hash = event.respond_to?(:to_hash) ? event.to_hash : event
      ImpulsoSentryScrub.call(hash)
    end
  end
end
