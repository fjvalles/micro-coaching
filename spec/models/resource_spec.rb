require "rails_helper"

RSpec.describe Resource do
  describe ".sendable" do
    it "returns kept approved resources verified recently" do
      recent = create(:resource, status: :approved, last_verified_at: 2.days.ago)
      create(:resource, status: :verified, last_verified_at: 2.days.ago)
      create(:resource, status: :approved, last_verified_at: 40.days.ago)
      discarded = create(:resource, status: :approved, last_verified_at: 2.days.ago)
      discarded.discard!

      expect(described_class.sendable).to contain_exactly(recent)
    end
  end

  describe ".for_program" do
    it "returns general resources and resources scoped to the program" do
      program = create(:program)
      other_program = create(:program)
      general = create(:resource, program: nil)
      scoped = create(:resource, program: program)
      create(:resource, program: other_program)

      expect(described_class.for_program(program)).to contain_exactly(general, scoped)
    end
  end

  describe ".stale" do
    it "returns resources with missing or old verification" do
      missing = create(:resource, last_verified_at: nil)
      old = create(:resource, last_verified_at: 31.days.ago)
      create(:resource, last_verified_at: 1.day.ago)

      expect(described_class.stale).to contain_exactly(missing, old)
    end
  end

  it "deduplicates URLs case-insensitively" do
    create(:resource, url: "https://example.com/One")

    duplicate = build(:resource, url: "https://example.com/one")
    expect(duplicate).not_to be_valid
  end
end
