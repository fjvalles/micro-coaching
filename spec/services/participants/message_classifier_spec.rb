require "rails_helper"

RSpec.describe Participants::MessageClassifier do
  let(:tz) { "America/Santiago" }
  let(:participant) { create(:participant, timezone: tz, initial_pattern: "X") }

  it "classifies free_user by default" do
    travel_to(Time.utc(2026, 5, 23, 15)) do
      result = described_class.new(participant: participant).classify
      expect(result.type).to eq(:free_user)
    end
  end

  it "classifies as program_intake while the participant is in intake, regardless of other state" do
    participant.update!(status: :intake, program: nil, current_day: 0, initial_pattern: nil)
    result = described_class.new(participant: participant).classify
    expect(result.type).to eq(:program_intake)
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
    create(:conversation, participant: participant, moment: :checkin_question, role: :assistant, day_number: participant.current_day, sent_at: now)
    result = described_class.new(participant: participant, now: now).classify
    expect(result.type).to eq(:checkin_response)
  end

  it "classifies stale unresolved pending check-ins as check-in responses" do
    sent_at = Time.use_zone(tz) { Time.zone.local(2026, 5, 23, 20, 0) }
    now = Time.use_zone(tz) { Time.zone.local(2026, 5, 24, 18, 0) }
    participant.update!(pending_checkin_at: sent_at)
    create(:conversation, participant: participant, moment: :checkin_question, role: :assistant, day_number: participant.current_day, sent_at: sent_at)

    result = described_class.new(participant: participant, now: now).classify

    expect(result.type).to eq(:checkin_response)
  end

  it "classifies free_user after the pending check-in was answered" do
    now = Time.use_zone(tz) { Time.zone.local(2026, 5, 24, 18, 0) }
    participant.update!(pending_checkin_at: now - 1.day)
    create(:conversation, participant: participant, moment: :checkin_question, role: :assistant, day_number: participant.current_day, sent_at: now - 1.day)
    create(:conversation, participant: participant, moment: :checkin_response, role: :user, day_number: participant.current_day)

    result = described_class.new(participant: participant, now: now).classify

    expect(result.type).to eq(:free_user)
  end

  it "free_user when window passed without pending" do
    now = Time.use_zone(tz) { Time.zone.local(2026, 5, 23, 21, 30) }
    result = described_class.new(participant: participant, now: now).classify
    expect(result.type).to eq(:free_user)
  end
end
