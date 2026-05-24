require "rails_helper"

RSpec.describe Participant, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:phone_e164) }
  it { is_expected.to validate_presence_of(:timezone) }
  it { is_expected.to define_enum_for(:status).with_values(pending: 0, active: 1, completed: 2, paused: 3) }
  it { is_expected.to have_many(:conversations) }
  it { is_expected.to have_many(:daily_reports) }

  describe "phone_e164 format" do
    it "accepts E.164" do
      expect(build(:participant, phone_e164: "+5215551234567")).to be_valid
    end

    it "rejects invalid format" do
      expect(build(:participant, phone_e164: "5551234567")).not_to be_valid
    end
  end

  describe "#phase" do
    let(:program) { create(:program) }

    before do
      (1..4).each   { |d| create(:day_content, program: program, day_number: d, phase: :see) }
      (5..10).each  { |d| create(:day_content, program: program, day_number: d, phase: :choose) }
      (11..14).each { |d| create(:day_content, program: program, day_number: d, phase: :anchor) }
    end

    it "returns :see for days 1-4" do
      [1, 2, 3, 4].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:see) }
    end
    it "returns :choose for days 5-10" do
      [5, 7, 10].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:choose) }
    end
    it "returns :anchor for days 11-14" do
      [11, 13, 14].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:anchor) }
    end
    it "returns :pending out of range" do
      expect(create(:participant, program: program, current_day: 0).phase).to eq(:pending)
    end
  end

  describe "#in_24h_window?" do
    let(:participant) { create(:participant) }

    it "false when no inbound" do
      expect(participant.in_24h_window?).to be false
    end

    it "true when recent inbound" do
      create(:conversation, participant: participant, role: :user, created_at: 1.hour.ago)
      expect(participant.in_24h_window?).to be true
    end

    it "false when stale inbound" do
      create(:conversation, participant: participant, role: :user, created_at: 30.hours.ago)
      expect(participant.in_24h_window?).to be false
    end
  end

  describe "soft delete" do
    it "discard sets discarded_at" do
      p = create(:participant)
      p.discard
      expect(p.discarded_at).to be_present
      expect(Participant.kept).not_to include(p)
    end
  end
end
