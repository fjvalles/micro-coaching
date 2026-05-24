OpenAI.configure do |config|
  config.access_token = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?
  config.request_timeout = 30
end if defined?(OpenAI)
