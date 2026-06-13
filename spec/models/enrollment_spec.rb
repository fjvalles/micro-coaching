require "rails_helper"

RSpec.describe Enrollment do
  it "is valid with the factory" do
    expect(build(:enrollment)).to be_valid
  end

  it "requires a positive cycle_number" do
    expect(build(:enrollment, cycle_number: 0)).not_to be_valid
  end

  it "enforces uniqueness of program per participant per cycle" do
    existing = create(:enrollment, cycle_number: 1)
    dup = build(:enrollment, participant: existing.participant, program: existing.program, cycle_number: 1)
    expect(dup).not_to be_valid
  end

  it "allows the same program again in a later cycle" do
    existing = create(:enrollment, cycle_number: 1)
    later = build(:enrollment, participant: existing.participant, program: existing.program, cycle_number: 2)
    expect(later).to be_valid
  end

  it "exposes status enum" do
    expect(described_class.statuses.keys).to contain_exactly("active", "completed", "canceled")
  end
end
