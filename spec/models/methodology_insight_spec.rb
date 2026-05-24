require "rails_helper"

RSpec.describe MethodologyInsight, type: :model do
  it { is_expected.to belong_to(:program).optional }
  it { is_expected.to validate_presence_of(:scope) }
  it { is_expected.to validate_presence_of(:generated_at) }

  it "validates scope inclusion" do
    insight = build(:methodology_insight, scope: "bogus")
    expect(insight).not_to be_valid
    expect(insight.errors[:scope]).to be_present
  end

  describe ".latest_for" do
    let!(:program) { create(:program) }

    it "returns the most recent insight for the given scope" do
      _old = create(:methodology_insight, scope: "phase_kpi", generated_at: 2.days.ago)
      recent = create(:methodology_insight, scope: "phase_kpi", generated_at: 1.hour.ago)
      create(:methodology_insight, scope: "stuck_pattern", generated_at: Time.current)

      expect(described_class.latest_for("phase_kpi")).to eq(recent)
    end

    it "filters by program when given" do
      create(:methodology_insight, scope: "phase_kpi", program: nil, generated_at: 1.hour.ago)
      scoped = create(:methodology_insight, scope: "phase_kpi", program: program, generated_at: 30.minutes.ago)

      expect(described_class.latest_for("phase_kpi", program: program)).to eq(scoped)
    end
  end
end
