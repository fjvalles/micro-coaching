require "rails_helper"

RSpec.describe Openai::ParticipantSummarizer do
  let(:participant) { create(:participant, ai_summary: "resumen previo") }
  let(:response) do
    Openai::Client::Result.new(content: "Resumen actualizado del participante.",
                               tokens_input: 10, tokens_output: 8, model: "gpt-4.1-mini", latency_ms: 12)
  end
  let(:client) { instance_double(Openai::Client, chat: response) }

  it "returns the rolling summary from the model" do
    result = described_class.new(participant: participant, client: client).call
    expect(result.summary).to eq("Resumen actualizado del participante.")
  end

  it "folds the prior summary and recent reports into the prompt" do
    create(:daily_report, participant: participant, day_number: 3, ai_summary: "avanzó un paso", ai_key_pattern: "evita exponerse")

    expect(client).to receive(:chat) do |messages:, **_|
      user = messages.last[:content]
      expect(user).to include("resumen previo")
      expect(user).to include("evita exponerse")
      response
    end

    described_class.new(participant: participant, client: client).call
  end
end
