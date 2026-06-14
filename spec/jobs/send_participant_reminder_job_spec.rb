require "rails_helper"

RSpec.describe SendParticipantReminderJob, type: :job do
  let(:participant) { create(:participant) }
  let(:reminder) { create(:participant_reminder, participant: participant, scheduled_at: 1.minute.ago) }

  it "sends the pending reminder once and marks it sent" do
    create(:conversation, participant: participant, role: :user, moment: :free_user, created_at: 1.hour.ago)
    sent_conversation = create(:conversation, participant: participant, role: :assistant)
    sender = instance_double(Outbound::AdminMessage)
    allow(sender).to receive(:call).and_return(Outbound::AdminMessage::Result.new(sent: true, conversation: sent_conversation))
    expect(Outbound::AdminMessage).to receive(:new).once.and_return(sender)

    2.times { described_class.new.perform(reminder.id) }

    expect(reminder.reload).to be_sent
    expect(reminder.sent_conversation).to eq(sent_conversation)
  end

  it "cancels when the participant is paused" do
    participant.update!(status: :paused)

    described_class.new.perform(reminder.id)

    expect(reminder.reload).to be_canceled
    expect(reminder.failure_reason).to eq("participant_paused")
  end

  it "fails outside the 24h window when no reminder template is configured" do
    Setting.set("participant_reminder_template_name", "")

    described_class.new.perform(reminder.id)

    expect(reminder.reload).to be_failed
    expect(reminder.failure_reason).to eq("outside_24h_window")
  end
end
