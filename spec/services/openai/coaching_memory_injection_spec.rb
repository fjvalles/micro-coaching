require "rails_helper"

# Guards the privacy contract: focus_hint and ai_summary ARE injected into the
# generative prompts; coach_notes is NEVER injected.
RSpec.describe "AI-safe coaching memory injection" do
  let(:participant) do
    create(:participant,
           focus_hint: "acompañar hacia activación física",
           ai_summary: "ha dado pequeños pasos esta semana",
           coach_notes: "SECRETO_CRUDO_NO_DEBE_FILTRARSE")
  end

  describe Openai::FreeResponseGenerator do
    subject(:prompt) do
      described_class.new(participant: participant, user_message: "hola").send(:system_prompt)
    end

    it "injects focus_hint and ai_summary" do
      expect(prompt).to include("acompañar hacia activación física")
      expect(prompt).to include("ha dado pequeños pasos esta semana")
    end

    it "never injects coach_notes" do
      expect(prompt).not_to include("SECRETO_CRUDO_NO_DEBE_FILTRARSE")
    end
  end

  describe Openai::MorningMessageGenerator do
    let(:day_content) { create(:day_content, program: participant.program, day_number: participant.current_day) }
    subject(:prompt) do
      described_class.new(participant: participant, day_content: day_content).send(:user_prompt)
    end

    it "injects focus_hint and ai_summary" do
      expect(prompt).to include("acompañar hacia activación física")
      expect(prompt).to include("ha dado pequeños pasos esta semana")
    end

    it "never injects coach_notes" do
      expect(prompt).not_to include("SECRETO_CRUDO_NO_DEBE_FILTRARSE")
    end
  end
end
