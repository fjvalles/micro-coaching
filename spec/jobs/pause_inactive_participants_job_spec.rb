require "rails_helper"

RSpec.describe PauseInactiveParticipantsJob, type: :job do
  before { Setting.set("inactivity_pause_days", 5) }

  it "pauses an active participant enrolled long ago with no inbound" do
    p = create(:participant, status: :active, enrolled_at: 10.days.ago)
    described_class.new.perform
    expect(p.reload.status).to eq("paused")
  end

  it "does not pause when there is a recent inbound" do
    p = create(:participant, status: :active, enrolled_at: 10.days.ago)
    create(:conversation, participant: p, role: :user, created_at: 1.day.ago)
    described_class.new.perform
    expect(p.reload.status).to eq("active")
  end

  it "does not pause within the enrollment grace window" do
    p = create(:participant, status: :active, enrolled_at: 1.day.ago)
    described_class.new.perform
    expect(p.reload.status).to eq("active")
  end

  it "ignores discarded inbounds when measuring inactivity" do
    p = create(:participant, status: :active, enrolled_at: 10.days.ago)
    create(:conversation, participant: p, role: :user, created_at: 1.day.ago, discarded_at: Time.current)
    described_class.new.perform
    expect(p.reload.status).to eq("paused")
  end

  it "is a no-op when inactivity_pause_days is 0" do
    Setting.set("inactivity_pause_days", 0)
    p = create(:participant, status: :active, enrolled_at: 30.days.ago)
    described_class.new.perform
    expect(p.reload.status).to eq("active")
  end

  it "leaves non-active participants untouched" do
    p = create(:participant, status: :completed, enrolled_at: 30.days.ago)
    described_class.new.perform
    expect(p.reload.status).to eq("completed")
  end
end
