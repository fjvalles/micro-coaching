require "rails_helper"

RSpec.describe ParticipantReminder, type: :model do
  it "validates status and required scheduling fields" do
    reminder = build(:participant_reminder, status: nil, scheduled_at: nil)

    expect(reminder).not_to be_valid
    expect(reminder.errors[:status]).to be_present
    expect(reminder.errors[:scheduled_at]).to be_present
  end

  it "finds pending reminders due by now" do
    due = create(:participant_reminder, scheduled_at: 1.minute.ago)
    create(:participant_reminder, scheduled_at: 1.hour.from_now)
    create(:participant_reminder, status: "sent", scheduled_at: 1.minute.ago)

    expect(described_class.due).to contain_exactly(due)
  end
end
