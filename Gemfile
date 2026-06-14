source "https://rubygems.org"

gem "rails", "~> 7.2.3", ">= 7.2.3.1"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "jsbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# App-specific
gem "redis", ">= 4.0.1"
# Sidekiq 7.3 calls ConnectionPool::TimedStack#pop with a positional timeout.
# connection_pool 3.x made that keyword-only, which kills Sidekiq's scheduler.
gem "connection_pool", "~> 2.5"
gem "sidekiq", "~> 7.0"
gem "sidekiq-cron", "~> 2.0"
gem "devise"
gem "ruby-openai", "~> 7.0"
gem "discard", "~> 1.3"
gem "dotenv-rails"
gem "httparty"
gem "faraday-retry"
gem "kramdown", "~> 2.4"
gem "kramdown-parser-gfm", "~> 1.1"
gem "aws-sdk-s3", "~> 1.144"
gem "paper_trail", "~> 16.0"
gem "rack-attack"

# Transactional email via Resend HTTP API (Hetzner blocks outbound SMTP ports)
gem "resend"

# Error tracking + alerting (only active when SENTRY_DSN is set)
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

# Payments — Transbank Webpay Plus (Chile)
gem "transbank-sdk", "~> 5.0"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
  gem "vcr"
  gem "webmock"
  gem "bullet"
end

group :development do
  gem "web-console"
  gem "foreman"
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "rails-controller-testing"
end

gem "rails-i18n", "~> 7.0"
