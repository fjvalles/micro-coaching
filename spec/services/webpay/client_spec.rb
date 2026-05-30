require "rails_helper"

RSpec.describe Webpay::Client do
  let(:tx) { instance_double(Transbank::Webpay::WebpayPlus::Transaction) }

  before do
    Setting.set("webpay_enabled", true)
    Setting.set("webpay_environment", "integration")
    allow(Transbank::Webpay::WebpayPlus::Transaction).to receive(:build_for_integration).and_return(tx)
  end

  describe "#create" do
    it "returns the token and redirect url" do
      allow(tx).to receive(:create).and_return("token" => "tok123", "url" => "https://wp/init")
      res = described_class.new.create(buy_order: "O1", session_id: "S1", amount: 15_000, return_url: "https://x/r")
      expect(res.success?).to be true
      expect(res.token).to eq("tok123")
      expect(res.url).to eq("https://wp/init")
    end

    it "is blocked by the webpay_enabled kill-switch" do
      Setting.set("webpay_enabled", false)
      res = described_class.new.create(buy_order: "O1", session_id: "S1", amount: 1, return_url: "r")
      expect(res.success?).to be false
    end

    it "captures SDK errors without raising" do
      allow(tx).to receive(:create).and_raise(StandardError.new("boom"))
      res = described_class.new.create(buy_order: "O", session_id: "S", amount: 1, return_url: "r")
      expect(res.success?).to be false
      expect(res.error).to eq("boom")
    end
  end

  describe "#commit" do
    it "maps an AUTHORIZED response" do
      allow(tx).to receive(:commit).and_return(
        "status" => "AUTHORIZED", "response_code" => 0, "amount" => 15_000,
        "authorization_code" => "1213", "payment_type_code" => "VD",
        "installments_number" => 0, "card_detail" => { "card_number" => "6623" }
      )
      res = described_class.new.commit(token: "tok")
      expect(res.success?).to be true
      expect(res.authorized).to be true
      expect(res.amount).to eq(15_000)
      expect(res.card_last4).to eq("6623")
    end

    it "marks a non-authorized response" do
      allow(tx).to receive(:commit).and_return("status" => "FAILED", "response_code" => -1)
      res = described_class.new.commit(token: "tok")
      expect(res.success?).to be true
      expect(res.authorized).to be false
    end
  end
end
