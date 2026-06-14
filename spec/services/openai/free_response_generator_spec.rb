require "rails_helper"

RSpec.describe Openai::FreeResponseGenerator do
  let(:participant) { create(:participant) }

  describe "#system_prompt" do
    subject(:prompt) do
      described_class.new(participant: participant, user_message: "hola").send(:system_prompt)
    end

    # Guards the conversational guardrails added after the day-1 pilot review:
    # no infinite somatic loop, varied acknowledgments, respect for autonomy.
    it "includes the conversational style guardrails" do
      expect(prompt).to include("Estilo de conversación")
      expect(prompt).to include("sensaciones corporales")
      expect(prompt).to include("Respeta la autonomía")
    end

    it "uses the editable Setting for style guardrails" do
      Setting.set("free_chat_style_guardrails", "- Responde con una sola pregunta y respeta la autonomía.")

      expect(prompt).to include("Responde con una sola pregunta")
    end

    it "falls back to the default style guardrails when the Setting is blank" do
      Setting.set("free_chat_style_guardrails", "")

      expect(prompt).to include("sensaciones corporales")
    end
  end

  describe "#call" do
    it "parses a catalog resource id from JSON output" do
      Setting.set("resource_catalog_enabled", true)
      resource = create(:resource, topics: [ "foco" ], program: participant.program)
      client = instance_double(Openai::Client)
      allow(client).to receive(:chat).and_return(
        Openai::Client::Result.new(
          content: { body: "Te dejo una práctica breve.", resource_id: resource.id }.to_json,
          tokens_input: 10,
          tokens_output: 5,
          model: "gpt-5-mini",
          latency_ms: 20
        )
      )
      allow(Openai::PromptLogger).to receive(:record)

      result = described_class.new(participant: participant, user_message: "me cuesta enfocarme", client: client).call

      expect(result.body).to eq("Te dejo una práctica breve.")
      expect(result.resource_id).to eq(resource.id)
      expect(result.resource_catalog).to be true
    end
  end
end
