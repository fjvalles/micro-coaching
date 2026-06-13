require "rails_helper"

RSpec.describe Participant, "enrollment helpers" do
  describe "#start_enrollment!" do
    it "opens an active cycle-1 ledger row for the current program" do
      participant = create(:participant)
      expect { participant.start_enrollment! }.to change { participant.enrollments.count }.by(1)
      enrollment = participant.enrollments.last
      expect(enrollment).to be_active
      expect(enrollment.cycle_number).to eq(1)
      expect(enrollment.program_id).to eq(participant.program_id)
    end

    it "is idempotent — no duplicate active row for the same program" do
      participant = create(:participant)
      participant.start_enrollment!
      expect { participant.start_enrollment! }.not_to(change { participant.enrollments.count })
    end

    it "increments cycle_number for a different program" do
      participant = create(:participant)
      participant.start_enrollment!
      other = create(:program)
      participant.start_enrollment!(other)
      expect(participant.enrollments.find_by(program_id: other.id).cycle_number).to eq(2)
    end

    it "no-ops when there is no program" do
      participant = create(:participant, program: nil)
      expect { participant.start_enrollment! }.not_to(change { participant.enrollments.count })
    end
  end

  describe "#current_enrollment" do
    it "returns the active row matching the participant's program" do
      participant = create(:participant)
      participant.start_enrollment!
      expect(participant.current_enrollment).to eq(participant.enrollments.active.first)
    end
  end
end
