require "rails_helper"

RSpec.describe MorningWakeJob, type: :job do
  it "enqueues per-participant job when local hour is 7" do
    tz = "America/Santiago"
    p = create(:participant, timezone: tz, current_day: 1, status: :active)
    travel_to Time.find_zone(tz).local(2026, 5, 23, 7, 5) do
      expect {
        described_class.new.perform
      }.to have_enqueued_job(MorningWakeForParticipantJob).with(p.id)
    end
  end

  it "skips when hour is not 7" do
    p = create(:participant, timezone: "America/Santiago", current_day: 1, status: :active)
    travel_to Time.find_zone("America/Santiago").local(2026, 5, 23, 9, 0) do
      expect {
        described_class.new.perform
      }.not_to have_enqueued_job(MorningWakeForParticipantJob)
    end
  end
end
