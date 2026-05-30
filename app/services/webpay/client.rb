require "transbank/sdk"

module Webpay
  # Thin wrapper over Transbank Webpay Plus. Honors the `webpay_enabled` kill-switch
  # and the `webpay_environment` Setting (integration uses the SDK's public test
  # credentials; production uses WEBPAY_COMMERCE_CODE / WEBPAY_API_KEY).
  class Client
    CreateResult = Struct.new(:success, :token, :url, :raw, :error, keyword_init: true) do
      def success? = success
    end

    CommitResult = Struct.new(
      :success, :authorized, :status, :amount, :authorization_code, :payment_type_code,
      :response_code, :installments, :card_last4, :raw, :error, keyword_init: true
    ) do
      def success? = success
    end

    def create(buy_order:, session_id:, amount:, return_url:)
      unless Setting.fetch("webpay_enabled")
        return CreateResult.new(success: false, error: "webpay_enabled=false (kill-switch activo)")
      end

      resp = transaction.create(buy_order, session_id, amount.to_i, return_url)
      CreateResult.new(success: true, token: resp["token"], url: resp["url"], raw: resp)
    rescue StandardError => e
      report(e, "create")
      CreateResult.new(success: false, error: e.message)
    end

    def commit(token:)
      resp = transaction.commit(token)
      authorized = resp["status"] == "AUTHORIZED" && resp["response_code"].to_i.zero?
      CommitResult.new(
        success: true,
        authorized: authorized,
        status: resp["status"],
        amount: resp["amount"],
        authorization_code: resp["authorization_code"],
        payment_type_code: resp["payment_type_code"],
        response_code: resp["response_code"],
        installments: resp["installments_number"],
        card_last4: resp.dig("card_detail", "card_number"),
        raw: resp
      )
    rescue StandardError => e
      report(e, "commit")
      CommitResult.new(success: false, authorized: false, error: e.message)
    end

    private

    def transaction
      @transaction ||=
        if production?
          Transbank::Webpay::WebpayPlus::Transaction.build_for_production(
            ENV.fetch("WEBPAY_COMMERCE_CODE"), ENV.fetch("WEBPAY_API_KEY")
          )
        else
          Transbank::Webpay::WebpayPlus::Transaction.build_for_integration(
            Transbank::Common::IntegrationCommerceCodes::WEBPAY_PLUS,
            Transbank::Common::IntegrationApiKeys::WEBPAY
          )
        end
    end

    def production?
      Setting.fetch("webpay_environment").to_s == "production" && ENV["WEBPAY_COMMERCE_CODE"].present?
    end

    def report(error, op)
      Rails.logger.error("Webpay::Client##{op} failed: #{error.class}: #{error.message}")
      Sentry.capture_exception(error) if defined?(Sentry) && Sentry.respond_to?(:capture_exception)
    end
  end
end
