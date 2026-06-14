require "rails_helper"

RSpec.describe SendProgramOverviewJob do
  let(:program) { create(:program, total_days: 7) }
  let(:participant) do
    create(:participant, program: program, status: :active, current_day: 1, started_at: 1.hour.ago)
  end

  before { create(:day_content, program: program, day_number: 1, phase: :see) }

  def open_window!(p)
    create(:conversation, participant: p, role: :user, moment: :free_user, created_at: 1.minute.ago)
  end

  it "sends the overview when the participant is starting and the 24h window is open" do
    open_window!(participant)
    allow(Whatsapp::Client).to receive(:new).and_return(
      instance_double(Whatsapp::Client, send_text: double(success?: true, wamid: "wamid.x", error: nil))
    )

    expect {
      described_class.perform_now(participant.id)
    }.to change { participant.conversations.where(moment: :program_overview).count }.by(1)
  end

  it "skips when the 24h window is closed (no prior inbound)" do
    expect(Whatsapp::Client).not_to receive(:new)
    expect {
      described_class.perform_now(participant.id)
    }.not_to change(Conversation, :count)
  end

  it "skips participants past the start of the program" do
    participant.update!(current_day: 5)
    open_window!(participant)
    expect(Whatsapp::Client).not_to receive(:new)
    described_class.perform_now(participant.id)
  end

  it "does not back-fill participants who started long ago" do
    participant.update!(started_at: 10.days.ago)
    open_window!(participant)
    expect(Whatsapp::Client).not_to receive(:new)
    described_class.perform_now(participant.id)
  end

  it "is idempotent once an overview has been sent" do
    open_window!(participant)
    create(:conversation, participant: participant, role: :assistant, moment: :program_overview, sent_at: Time.current)
    expect(Whatsapp::Client).not_to receive(:new)
    described_class.perform_now(participant.id)
  end
end
