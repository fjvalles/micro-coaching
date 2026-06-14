require "rails_helper"

RSpec.describe Participant, type: :model do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:phone_e164) }
  it { is_expected.to validate_presence_of(:timezone) }
  it { is_expected.to define_enum_for(:status).with_values(pending: 0, active: 1, completed: 2, paused: 3, awaiting_payment: 4, intake: 5) }
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

  describe "current_day validation" do
    let(:program) { create(:program, total_days: 7) }

    it "allows days within the program range" do
      expect(build(:participant, program: program, current_day: 7)).to be_valid
    end

    it "rejects days beyond the program range" do
      participant = build(:participant, program: program, current_day: 8)

      expect(participant).not_to be_valid
      expect(participant.errors[:current_day]).to include("must be within the program range")
    end

    it "allows the completed sentinel day only for completed participants" do
      expect(build(:participant, program: program, status: :completed, current_day: 8)).to be_valid
      expect(build(:participant, program: program, status: :active, current_day: 8)).not_to be_valid
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
      [ 1, 2, 3, 4 ].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:see) }
    end
    it "returns :choose for days 5-10" do
      [ 5, 7, 10 ].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:choose) }
    end
    it "returns :anchor for days 11-14" do
      [ 11, 13, 14 ].each { |d| expect(create(:participant, program: program, current_day: d).phase).to eq(:anchor) }
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

  describe "#free_inbounds_today" do
    let(:participant) { create(:participant, timezone: "America/Santiago") }

    it "counts only free_user inbound messages from today" do
      create(:conversation, participant: participant, role: :user, moment: :free_user)
      create(:conversation, participant: participant, role: :user, moment: :free_user)
      create(:conversation, participant: participant, role: :user, moment: :checkin_response)
      create(:conversation, participant: participant, role: :assistant, moment: :free_assistant)
      expect(participant.free_inbounds_today).to eq(2)
    end

    it "excludes messages from previous days" do
      create(:conversation, participant: participant, role: :user, moment: :free_user, created_at: 2.days.ago)
      expect(participant.free_inbounds_today).to eq(0)
    end
  end

  describe "#last_inbound_at" do
    let(:participant) { create(:participant) }

    it "returns the most recent inbound timestamp" do
      create(:conversation, participant: participant, role: :user, created_at: 3.days.ago)
      recent = create(:conversation, participant: participant, role: :user, created_at: 1.hour.ago)
      expect(participant.last_inbound_at).to be_within(1.second).of(recent.created_at)
    end

    it "is nil when there are no inbound messages" do
      expect(participant.last_inbound_at).to be_nil
    end
  end

  describe "company membership" do
    it "coach_name returns the company override" do
      company = create(:company, coach_name: "Sofía")
      expect(create(:participant, company: company).coach_name).to eq("Sofía")
    end

    it "coach_name is nil without a company override" do
      expect(create(:participant, company: nil).coach_name).to be_nil
    end

    it "individuals pay individually" do
      expect(create(:participant, company: nil).pays_individually?).to be true
    end

    it "covered company members do not pay individually" do
      company = create(:company, covers_membership: true)
      expect(create(:participant, company: company).pays_individually?).to be false
    end

    it "company members pay individually if the company opts out of coverage" do
      company = create(:company, covers_membership: false)
      expect(create(:participant, company: company).pays_individually?).to be true
    end
  end

  describe "#payment_required?" do
    before do
      Setting.set("webpay_enabled", true)
      Setting.set("membership_price_clp", 15_000)
    end

    it "is true for an individual when membership is charged" do
      expect(create(:participant, company: nil).payment_required?).to be true
    end

    it "is false when Webpay is disabled" do
      Setting.set("webpay_enabled", false)
      expect(create(:participant, company: nil).payment_required?).to be false
    end

    it "is false when the price is zero" do
      Setting.set("membership_price_clp", 0)
      expect(create(:participant, company: nil).payment_required?).to be false
    end

    it "is false for a covered company member" do
      company = create(:company, covers_membership: true)
      expect(create(:participant, company: company).payment_required?).to be false
    end
  end
end
