require "transbank/sdk"

module Webpay
  # Webpay Oneclick (Mall) wrapper for recurring billing: one-time card inscription
  # (tokenization) plus later token charges. Honors the `webpay_oneclick_enabled`
  # kill-switch and the `webpay_environment` Setting (integration = SDK test creds;
  # production = ENV WEBPAY_ONECLICK_COMMERCE_CODE / WEBPAY_ONECLICK_CHILD_COMMERCE_CODE
  # / WEBPAY_ONECLICK_API_KEY).
  #
  # Oneclick is a two-store ("mall") product: a parent commerce code builds the
  # inscription/transaction and a child commerce code receives each charge.
  #
  # NOTE: response field names follow the Transbank Ruby SDK; verify against a real
  # integration run when production credentials land (kill-switch stays off until then).
  class OneclickClient
    StartResult  = Struct.new(:success, :token, :url, :raw, :error, keyword_init: true) { def success? = success }
    FinishResult = Struct.new(:success, :tbk_user, :card_last4, :authorization_code, :response_code, :raw, :error, keyword_init: true) { def success? = success }
    ChargeResult = Struct.new(:success, :authorized, :status, :amount, :buy_order, :authorization_code, :payment_type_code, :response_code, :installments, :raw, :error, keyword_init: true) { def success? = success }

    # Step 1: begin card inscription. Returns a token + Webpay URL to redirect to.
    def start_inscription(username:, email:, response_url:)
      return StartResult.new(success: false, error: kill_switch_msg) unless enabled?

      resp = inscription.start(username, email, response_url)
      StartResult.new(success: true, token: resp["token"], url: resp["url_webpay"], raw: resp)
    rescue StandardError => e
      report(e, "start_inscription")
      StartResult.new(success: false, error: e.message)
    end

    # Step 2: confirm inscription on return; yields the recurring tbk_user token.
    def finish_inscription(token:)
      resp = inscription.finish(token)
      FinishResult.new(
        success:            resp["response_code"].to_i.zero? && resp["tbk_user"].present?,
        tbk_user:           resp["tbk_user"],
        card_last4:         (resp.dig("card_detail", "card_number_4_last_digits") || resp["card_number"]).to_s.last(4),
        authorization_code: resp["authorization_code"],
        response_code:      resp["response_code"],
        raw:                resp
      )
    rescue StandardError => e
      report(e, "finish_inscription")
      FinishResult.new(success: false, error: e.message)
    end

    # Step 3 (recurring): charge a stored token. Used for the first charge and by
    # SubscriptionBillingJob for each cycle.
    def charge(username:, tbk_user:, buy_order:, amount:)
      return ChargeResult.new(success: false, authorized: false, error: kill_switch_msg) unless enabled?

      details = [ { commerce_code: child_commerce_code, buy_order: buy_order, amount: amount.to_i, installments_number: 0 } ]
      resp   = transaction.authorize(username, tbk_user, buy_order, details)
      detail = Array(resp["details"]).first || {}
      authorized = detail["status"] == "AUTHORIZED" && detail["response_code"].to_i.zero?
      ChargeResult.new(
        success:            true,
        authorized:         authorized,
        status:             detail["status"],
        amount:             detail["amount"],
        buy_order:          detail["buy_order"],
        authorization_code: detail["authorization_code"],
        payment_type_code:  detail["payment_type_code"],
        response_code:      detail["response_code"],
        installments:       detail["installments_number"],
        raw:                resp
      )
    rescue StandardError => e
      report(e, "charge")
      ChargeResult.new(success: false, authorized: false, error: e.message)
    end

    def delete_inscription(username:, tbk_user:)
      inscription.delete(tbk_user, username)
      true
    rescue StandardError => e
      report(e, "delete_inscription")
      false
    end

    private

    def enabled?      = Setting.fetch("webpay_oneclick_enabled")
    def kill_switch_msg = "webpay_oneclick_enabled=false (kill-switch activo)"

    def inscription
      @inscription ||= build(Transbank::Webpay::Oneclick::MallInscription)
    end

    def transaction
      @transaction ||= build(Transbank::Webpay::Oneclick::MallTransaction)
    end

    def build(klass)
      if production?
        klass.build_for_production(ENV.fetch("WEBPAY_ONECLICK_COMMERCE_CODE"), ENV.fetch("WEBPAY_ONECLICK_API_KEY"))
      else
        klass.build_for_integration(
          Transbank::Common::IntegrationCommerceCodes::ONECLICK_MALL,
          Transbank::Common::IntegrationApiKeys::WEBPAY
        )
      end
    end

    def child_commerce_code
      if production?
        ENV.fetch("WEBPAY_ONECLICK_CHILD_COMMERCE_CODE")
      else
        Transbank::Common::IntegrationCommerceCodes::ONECLICK_MALL_CHILD1
      end
    end

    def production?
      Setting.fetch("webpay_environment").to_s == "production" && ENV["WEBPAY_ONECLICK_COMMERCE_CODE"].present?
    end

    def report(error, op)
      Rails.logger.error("Webpay::OneclickClient##{op} failed: #{error.class}: #{error.message}")
      Sentry.capture_exception(error) if defined?(Sentry) && Sentry.respond_to?(:capture_exception)
    end
  end
end
