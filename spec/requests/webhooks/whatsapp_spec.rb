require "rails_helper"

RSpec.describe "Webhooks::Whatsapp", type: :request do
  before do
    ENV["META_WEBHOOK_VERIFY_TOKEN"] = "verify_xyz"
    ENV["META_APP_SECRET"] = "sec"
  end

  describe "GET verify" do
    it "echoes challenge with correct token" do
      get "/webhooks/whatsapp", params: { "hub.verify_token" => "verify_xyz", "hub.challenge" => "12345" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("12345")
    end

    it "rejects bad token" do
      get "/webhooks/whatsapp", params: { "hub.verify_token" => "bad" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST receive" do
    let(:body) { '{"entry":[]}' }
    let(:signature) { "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", "sec", body) }

    it "queues job with valid signature" do
      expect {
        post "/webhooks/whatsapp", params: body,
             headers: { "X-Hub-Signature-256" => signature, "Content-Type" => "application/json" }
      }.to have_enqueued_job(ProcessIncomingMessageJob)
      expect(response).to have_http_status(:ok)
    end

    it "rejects bad signature" do
      post "/webhooks/whatsapp", params: body,
           headers: { "X-Hub-Signature-256" => "sha256=badbeef", "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
