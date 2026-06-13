require "rails_helper"

RSpec.describe Participants::Activator do
  describe "#call" do
    it "activates a non-active participant on day 1 and sends the welcome" do
      participant = create(:participant, status: :awaiting_payment, current_day: 0, started_at: nil)
      expect(SendWelcomeJob).to receive(:perform_later).with(participant.id)

      described_class.new(participant).call

      expect(participant.reload).to be_active
      expect(participant.current_day).to eq(1)
      expect(participant.started_at).to be_present
    end

    it "opens the cycle-1 enrollment ledger row" do
      participant = create(:participant, status: :awaiting_payment, current_day: 0, started_at: nil)
      allow(SendWelcomeJob).to receive(:perform_later)

      described_class.new(participant).call

      enrollment = participant.reload.current_enrollment
      expect(enrollment).to be_present
      expect(enrollment.cycle_number).to eq(1)
    end

    it "is idempotent — no-op and no welcome when already active" do
      participant = create(:participant, status: :active)
      expect(SendWelcomeJob).not_to receive(:perform_later)

      described_class.new(participant).call

      expect(participant.reload).to be_active
    end
  end
end
