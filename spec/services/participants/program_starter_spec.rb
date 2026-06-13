require "rails_helper"

RSpec.describe Participants::ProgramStarter do
  include ActiveJob::TestHelper

  describe "#call" do
    let(:program) { create(:program) }

    before do
      create(:day_content, program: program, day_number: 1)
    end

    it "activates a pending participant and enqueues welcome plus day-1 wake" do
      participant = create(:participant, program: program, status: :pending, current_day: 0, started_at: nil)

      result = nil
      expect {
        result = described_class.new(participant).call
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)
        .and have_enqueued_job(MorningWakeForParticipantJob).with(participant.id)

      expect(result).to be_ok
      expect(participant.reload).to be_active
      expect(participant.current_day).to eq(1)
      expect(participant.started_at).to be_present
      expect(participant.current_enrollment).to be_present
    end

    it "starts an already active day-1 participant without resetting the program" do
      participant = create(:participant, program: program, status: :active, current_day: 1, enrolled_at: nil, started_at: nil)

      result = nil
      expect {
        result = described_class.new(participant).call
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)
        .and have_enqueued_job(MorningWakeForParticipantJob).with(participant.id)

      expect(result).to be_ok
      expect(participant.reload.current_day).to eq(1)
      expect(participant.started_at).to be_present
      expect(participant.current_enrollment).to be_present
    end

    it "does not start participants past day one" do
      participant = create(:participant, program: program, status: :active, current_day: 2)

      result = nil
      expect {
        result = described_class.new(participant).call
      }.not_to have_enqueued_job(MorningWakeForParticipantJob)

      expect(result).not_to be_ok
      expect(result.reason).to eq(:already_past_day_one)
    end
  end
end
