require "rails_helper"

RSpec.describe Participants::Enroller do
  let!(:program) { create(:program) }

  describe "#call" do
    it "activates immediately and sends welcome when no payment is required" do
      expect(SendWelcomeJob).to receive(:perform_later)

      participant = described_class.new(name: "Ana", phone_e164: "+56911112222").call

      expect(participant).to be_active
      expect(participant.current_day).to eq(1)
      expect(participant.started_at).to be_present
    end

    context "when individual membership is charged" do
      before do
        Setting.set("webpay_enabled", true)
        Setting.set("membership_price_clp", 15_000)
      end

      it "leaves the participant awaiting_payment and sends no welcome" do
        expect(SendWelcomeJob).not_to receive(:perform_later)

        participant = described_class.new(name: "Ana", phone_e164: "+56911113333").call

        expect(participant).to be_awaiting_payment
        expect(participant.current_day).to eq(0)
        expect(participant.started_at).to be_nil
      end
    end

    it "stores a free-text company on the legacy string column" do
      participant = described_class.new(name: "Ana", phone_e164: "+56911114444", company: "ACME").call
      expect(participant[:company]).to eq("ACME")
    end
  end
end
