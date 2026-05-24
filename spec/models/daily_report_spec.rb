require "rails_helper"

RSpec.describe DailyReport, type: :model do
  it { is_expected.to belong_to(:participant) }
  it { is_expected.to validate_presence_of(:day_number) }

  it "Participant#latest_report returns most recent" do
    p = create(:participant)
    create(:daily_report, participant: p, day_number: 1, reported_at: 2.days.ago)
    r2 = create(:daily_report, participant: p, day_number: 2, reported_at: 1.day.ago)
    expect(p.latest_report).to eq(r2)
  end
end
