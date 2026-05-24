require "rails_helper"

RSpec.describe Participants::MessageClassifier do
  let(:tz) { "America/Santiago" }
  let(:participant) { create(:participant, timezone: tz, initial_pattern: "X") }

  it "classifies free_user by default" do
    Timecop.freeze(Time.utc(2026, 5, 23, 15)) do
      result = described_class.new(participant: participant).classify
      expect(result.type).to eq(:free_user)
    end
  rescue NameError
    skip "Timecop not present"
  end

  it "classifies as initial_pattern_answer when no pattern + welcome exists" do
    participant.update!(initial_pattern: nil)
    create(:conversation, participant: participant, moment: :welcome, role: :assistant)
    result = described_class.new(participant: participant).classify
    expect(result.type).to eq(:initial_pattern_answer)
  end

  it "classifies checkin_response in window with pending" do
    now = Time.use_zone(tz) { Time.zone.local(2026, 5, 23, 20, 30) }
    participant.update!(pending_checkin_at: now)
    result = described_class.new(participant: participant, now: now).classify
    expect(result.type).to eq(:checkin_response)
  end

  it "free_user when window passed without pending" do
    now = Time.use_zone(tz) { Time.zone.local(2026, 5, 23, 21, 30) }
    result = described_class.new(participant: participant, now: now).classify
    expect(result.type).to eq(:free_user)
  end
end
