require "rails_helper"

RSpec.describe ParticipantReminders::Parser do
  let(:participant) { create(:participant, timezone: "America/Santiago") }
  let(:now) { Time.zone.parse("2026-06-14 12:04:00 -0400") }

  it "parses a same-day pm reminder request" do
    result = described_class.new(
      participant: participant,
      text: "Sí. Avísame a las 5pm",
      now: now
    ).call

    expect(result).to be_reminder
    expect(result.scheduled_at.in_time_zone("America/Santiago")).to eq(Time.zone.parse("2026-06-14 17:00:00 -0400"))
  end

  it "parses relative reminders" do
    result = described_class.new(participant: participant, text: "recuérdame en 2 horas", now: now).call

    expect(result.scheduled_at).to eq(now + 2.hours)
  end

  it "rejects unsupported non-program reminders" do
    result = described_class.new(participant: participant, text: "recuérdame llamar al doctor a las 5pm", now: now).call

    expect(result).not_to be_reminder
    expect(result.reason).to eq("unsupported reminder content")
  end
end
