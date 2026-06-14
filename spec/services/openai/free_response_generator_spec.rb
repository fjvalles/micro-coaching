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
end
