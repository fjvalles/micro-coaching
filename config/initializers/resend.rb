# Resend transactional email (HTTP API). The resend gem registers the :resend
# ActionMailer delivery method (see config/environments/production.rb). Sending
# is a no-op without an API key — empty RESEND_API_KEY simply means no real send,
# which is the expected state in dev/test.
Resend.api_key = ENV["RESEND_API_KEY"] if ENV["RESEND_API_KEY"].present?
