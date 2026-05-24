class Rack::Attack
  # Throttle WhatsApp webhook by IP: 60 requests/minute
  # Meta Cloud API sends from a known IP range but can burst; this stops abuse
  throttle("webhooks/whatsapp/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks/whatsapp") && req.post?
  end

  # Throttle admin login attempts: 5 per 20s per IP (brute-force protection)
  throttle("admin/login/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/admin_users/sign_in" && req.post?
  end

  # Throttle admin login by email: 10 per 5min (credential stuffing)
  throttle("admin/login/email", limit: 10, period: 5.minutes) do |req|
    if req.path == "/admin_users/sign_in" && req.post?
      req.params.dig("admin_user", "email").to_s.downcase.presence
    end
  end

  self.throttled_responder = lambda do |req|
    [ 429, { "Content-Type" => "text/plain" }, [ "Rate limit exceeded. Try again later.\n" ] ]
  end
end

# Wire Redis store after Rails initializes.
# RedisCacheStore is broken on Ruby 4.0 / connection_pool 3.x (ConnectionPool API change).
# Pass the Redis client directly — rack-attack 6.x supports it natively.
Rails.application.config.after_initialize do
  if defined?(Redis)
    Rack::Attack.cache.store = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end
end
