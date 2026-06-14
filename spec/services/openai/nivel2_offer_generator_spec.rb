require "rails_helper"

RSpec.describe Openai::Nivel2OfferGenerator do
  let(:participant) { create(:participant, name: "Ana", initial_pattern: "reviso el celular al despertar") }

  describe "#call" do
    it "returns the model's story body and token accounting" do
      client = instance_double(Openai::Client)
      allow(client).to receive(:chat).and_return(
        Openai::Client::Result.new(
          content: "Ana, mira lo que construiste en 14 días.",
          tokens_input: 30, tokens_output: 12, model: "gpt-4.1-mini", latency_ms: 18
        )
      )
      allow(Openai::PromptLogger).to receive(:record)

      result = described_class.new(participant: participant, client: client).call

      expect(result.body).to eq("Ana, mira lo que construiste en 14 días.")
      expect(result.tokens_input).to eq(30)
      expect(result.model).to eq("gpt-4.1-mini")
    end
  end

  describe "dry_run" do
    it "returns a stub body without calling the client" do
      client = instance_double(Openai::Client)
      expect(client).not_to receive(:chat)

      result = described_class.new(participant: participant, client: client).call(dry_run: true)

      expect(result.model).to eq("dry-run")
      expect(result.body).to include("Ana")
    end
  end
end
