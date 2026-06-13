require "rails_helper"

RSpec.describe Participants::ReEnroller do
  describe "#call" do
    it "transitions the participant into the program's next_program" do
      nivel2 = create(:program)
      nivel1 = create(:program, next_program: nivel2)
      participant = create(:participant, program: nivel1, status: :completed, current_day: 15)
      participant.enrollments.create!(program: nivel1, cycle_number: 1, status: :completed)
      allow(SendWelcomeJob).to receive(:perform_later)

      result = described_class.new(participant).call

      expect(result.ok).to be true
      participant.reload
      expect(participant.program).to eq(nivel2)
      expect(participant.current_day).to eq(1)
      expect(participant).to be_active
      expect(participant.current_enrollment.program).to eq(nivel2)
      expect(participant.current_enrollment.cycle_number).to eq(2)
    end

    it "fires the welcome and resets the rolling AI memory" do
      nivel2 = create(:program)
      nivel1 = create(:program, next_program: nivel2)
      participant = create(:participant, program: nivel1, ai_summary: "memoria vieja", ai_summary_updated_at: Time.current)
      expect(SendWelcomeJob).to receive(:perform_later).with(participant.id)

      described_class.new(participant).call

      expect(participant.reload.ai_summary).to be_nil
    end

    it "cancels a stale active cycle from the previous program" do
      nivel2 = create(:program)
      nivel1 = create(:program, next_program: nivel2)
      participant = create(:participant, program: nivel1)
      stale = participant.enrollments.create!(program: nivel1, cycle_number: 1, status: :active)
      allow(SendWelcomeJob).to receive(:perform_later)

      described_class.new(participant).call

      expect(stale.reload).to be_canceled
    end

    it "returns ok: false when there is no target program" do
      participant = create(:participant, program: create(:program, next_program: nil))
      allow(SendWelcomeJob).to receive(:perform_later)

      result = described_class.new(participant).call

      expect(result.ok).to be false
    end

    it "accepts an explicit target program" do
      participant = create(:participant)
      target = create(:program)
      allow(SendWelcomeJob).to receive(:perform_later)

      described_class.new(participant, program: target).call

      expect(participant.reload.program).to eq(target)
    end
  end
end
