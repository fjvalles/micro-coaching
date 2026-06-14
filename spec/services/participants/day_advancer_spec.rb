require "rails_helper"

RSpec.describe Participants::DayAdvancer do
  let(:tz) { "America/Santiago" }
  let(:participant) { create(:participant, current_day: 3, timezone: tz, status: :active) }

  it "advances when checkin recorded today" do
    create(:conversation, participant: participant, moment: :checkin_response,
           day_number: 3, role: :user, created_at: Time.current)
    result = described_class.new(participant: participant).call
    expect(result).to eq(:advanced)
    expect(participant.reload.current_day).to eq(4)
  end

  it "does not advance without checkin" do
    result = described_class.new(participant: participant).call
    expect(result).to eq(:no_checkin)
    expect(participant.reload.current_day).to eq(3)
  end

  it "completes on day 14 and enqueues manifesto" do
    participant.update!(current_day: 14)
    create(:conversation, participant: participant, moment: :checkin_response,
           day_number: 14, role: :user, created_at: Time.current)
    expect {
      described_class.new(participant: participant).call
    }.to have_enqueued_job(GenerateAndSendManifestoJob).with(participant.id)
    expect(participant.reload.status).to eq("completed")
    expect(participant.current_day).to eq(15)
  end

  it "enqueues the day-14 Nivel 2 offer on completion" do
    participant.update!(current_day: 14)
    create(:conversation, participant: participant, moment: :checkin_response,
           day_number: 14, role: :user, created_at: Time.current)
    expect {
      described_class.new(participant: participant).call
    }.to have_enqueued_job(SendNivel2OfferJob).with(participant.id)
  end

  it "skips paused participants" do
    participant.update!(status: :paused)
    expect(described_class.new(participant: participant).call).to eq(:skipped)
  end
end
