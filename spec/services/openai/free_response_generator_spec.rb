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
  end
end
