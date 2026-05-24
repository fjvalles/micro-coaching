if Rails.env.production?
  REQUIRED_ENV_VARS = %w[
    META_APP_SECRET
    META_ACCESS_TOKEN
    META_PHONE_NUMBER_ID
    META_WEBHOOK_VERIFY_TOKEN
    OPENAI_API_KEY
    RESEND_API_KEY
  ].freeze

  missing = REQUIRED_ENV_VARS.select { |var| ENV[var].blank? }

  if missing.any?
    raise "Missing required environment variables: #{missing.join(', ')}"
  end
end
