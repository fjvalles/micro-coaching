module Webhooks
  class WhatsappController < ActionController::API
    def verify
      if params["hub.verify_token"].to_s == ENV["META_WEBHOOK_VERIFY_TOKEN"].to_s && ENV["META_WEBHOOK_VERIFY_TOKEN"].present?
        render plain: params["hub.challenge"].to_s
      else
        head :forbidden
      end
    end

    def receive
      raw_body = request.raw_post
      signature = request.headers["X-Hub-Signature-256"]

      unless Whatsapp::SignatureVerifier.valid?(payload: raw_body, signature: signature)
        head :unauthorized and return
      end

      payload = JSON.parse(raw_body) rescue {}
      ProcessIncomingMessageJob.perform_later(payload) if payload.present?
      head :ok
    end
  end
end
