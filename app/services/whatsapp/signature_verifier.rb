module Whatsapp
  class SignatureVerifier
    def self.valid?(payload:, signature:)
      return false if signature.blank? || payload.blank?
      secret = ENV.fetch("META_APP_SECRET", "")
      return false if secret.blank?

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end
  end
end
