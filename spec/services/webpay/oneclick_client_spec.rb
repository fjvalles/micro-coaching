require "rails_helper"

RSpec.describe Webpay::OneclickClient do
  let(:inscription) { double("MallInscription") }
  let(:transaction) { double("MallTransaction") }

  before do
    Setting.set("webpay_oneclick_enabled", true)
    Setting.set("webpay_environment", "integration")
    allow(Transbank::Webpay::Oneclick::MallInscription).to receive(:build_for_integration).and_return(inscription)
    allow(Transbank::Webpay::Oneclick::MallTransaction).to receive(:build_for_integration).and_return(transaction)
  end

  describe "#start_inscription" do
    it "returns the token and url on success" do
      allow(inscription).to receive(:start).and_return({ "token" => "tok", "url_webpay" => "https://wp/oneclick" })

      result = described_class.new.start_inscription(username: "u", email: "e@x.cl", response_url: "https://app/ret")

      expect(result).to be_success
      expect(result.token).to eq("tok")
      expect(result.url).to eq("https://wp/oneclick")
    end

    it "is blocked by the kill-switch" do
      Setting.set("webpay_oneclick_enabled", false)

      result = described_class.new.start_inscription(username: "u", email: "e", response_url: "r")

      expect(result).not_to be_success
      expect(result.error).to include("kill-switch")
    end
  end

  describe "#finish_inscription" do
    it "extracts the recurring tbk_user token and card last 4" do
      allow(inscription).to receive(:finish).and_return(
        { "response_code" => 0, "tbk_user" => "tbk-xyz", "card_number" => "1234" }
      )

      result = described_class.new.finish_inscription(token: "tok")

      expect(result).to be_success
      expect(result.tbk_user).to eq("tbk-xyz")
      expect(result.card_last4).to eq("1234")
    end
  end

  describe "#charge" do
    it "normalizes an authorized mall detail" do
      allow(transaction).to receive(:authorize).and_return(
        { "details" => [ { "status" => "AUTHORIZED", "response_code" => 0, "amount" => 15_000,
                           "buy_order" => "B1", "authorization_code" => "A1", "payment_type_code" => "VN", "installments_number" => 0 } ] }
      )

      result = described_class.new.charge(username: "u", tbk_user: "t", buy_order: "B1", amount: 15_000)

      expect(result).to be_success
      expect(result.authorized).to be true
      expect(result.amount).to eq(15_000)
    end

    it "marks not-authorized when the detail is rejected" do
      allow(transaction).to receive(:authorize).and_return(
        { "details" => [ { "status" => "FAILED", "response_code" => -1 } ] }
      )

      result = described_class.new.charge(username: "u", tbk_user: "t", buy_order: "B1", amount: 15_000)

      expect(result.authorized).to be false
    end

    it "is blocked by the kill-switch" do
      Setting.set("webpay_oneclick_enabled", false)

      result = described_class.new.charge(username: "u", tbk_user: "t", buy_order: "B1", amount: 15_000)

      expect(result.authorized).to be false
      expect(result.error).to include("kill-switch")
    end
  end
end
