require "net/http"

module Whatsapp
  class Client
    Response = Struct.new(:success?, :wamid, :raw, :error, keyword_init: true)

    BASE = "https://graph.facebook.com".freeze
    DEFAULT_MAX_ATTEMPTS = 3

    def send_template(to:, template_name:, locale: ENV.fetch("PROGRAM_LOCALE", "es_MX"), components: [])
      post({
        messaging_product: "whatsapp",
        to: to,
        type: "template",
        template: {
          name: template_name,
          language: { code: locale },
          components: components
        }
      })
    end

    def send_text(to:, body:)
      post({
        messaging_product: "whatsapp",
        to: to,
        type: "text",
        text: { preview_url: false, body: body }
      })
    end

    def mark_as_read(message_id:)
      post({
        messaging_product: "whatsapp",
        status: "read",
        message_id: message_id
      })
    end

    private

    def post(payload)
      unless Setting.fetch("whatsapp_send_enabled")
        return Response.new(success?: false, error: "whatsapp_send_enabled=false (kill-switch activo)")
      end

      max_attempts = (Setting.fetch("whatsapp_retry_max") || DEFAULT_MAX_ATTEMPTS).to_i
      api_version  = Setting.fetch("meta_api_version").presence || ENV.fetch("META_API_VERSION", "v25.0")
      uri = URI("#{BASE}/#{api_version}/#{ENV.fetch('META_PHONE_NUMBER_ID')}/messages")
      json_body = payload.to_json

      max_attempts.times do |attempt|
        response, parsed = perform_request(uri, json_body)
        return build_response(response, parsed) if response.code.to_i.between?(200, 299)

        if retryable?(response.code.to_i) && attempt < max_attempts - 1
          sleep(0.5 * (2**(attempt + 1)))
          next
        end

        return Response.new(success?: false, raw: parsed, error: build_error_message(parsed, response.body))
      end
    rescue StandardError => e
      Rails.logger.error("Whatsapp::Client error: #{e.class}: #{e.message}")
      Response.new(success?: false, error: e.message)
    end

    def perform_request(uri, json_body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 15

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{ENV.fetch('META_ACCESS_TOKEN')}"
      request["Content-Type"] = "application/json"
      request.body = json_body

      response = http.request(request)
      parsed = JSON.parse(response.body) rescue {}
      [ response, parsed ]
    end

    def build_response(response, parsed)
      wamid = parsed.dig("messages", 0, "id")
      Response.new(success?: true, wamid: wamid, raw: parsed)
    end

    def retryable?(code)
      code == 429 || (500..599).cover?(code)
    end

    def build_error_message(parsed, fallback)
      meta_error = parsed["error"] || {}
      message = meta_error["message"].presence || fallback
      code = meta_error["code"]

      return message if code.blank?

      if code == 131030
        "#{message}. En Meta test mode, agrega este numero a la allowed list o usa un sender de produccion."
      else
        "(##{code}) #{message}"
      end
    end
  end
end
