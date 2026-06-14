require "rails_helper"

RSpec.describe ParticipantReminders::Scheduler do
  let(:participant) { create(:participant, timezone: "America/Santiago") }
  let(:source_conversation) { create(:conversation, participant: participant, role: :user, moment: :free_user) }
  let(:now) { Time.zone.parse("2026-06-14 12:04:00 -0400") }

  before do
    Setting.set("participant_reminders_enabled", true)
    Setting.set("participant_reminder_min_lead_minutes", 2)
    Setting.set("participant_reminder_max_horizon_days", 30)
    Setting.set("participant_reminder_max_active", 3)
    Setting.set("participant_reminder_max_per_day", 2)
    Setting.set("participant_reminder_quiet_hours_start", 22)
    Setting.set("participant_reminder_quiet_hours_end", 7)
  end

  it "creates a pending reminder and schedules the send job" do
    expect {
      described_class.new(
        participant: participant,
        text: "Avísame a las 5pm",
        source_conversation: source_conversation,
        now: now
      ).call
    }.to change(ParticipantReminder, :count).by(1)
      .and have_enqueued_job(SendParticipantReminderJob)

    reminder = ParticipantReminder.last
    expect(reminder.participant).to eq(participant)
    expect(reminder.source_conversation).to eq(source_conversation)
    expect(reminder.scheduled_at.in_time_zone("America/Santiago").hour).to eq(17)
  end

  it "does not create duplicates for the same source conversation" do
    scheduler = described_class.new(
      participant: participant,
      text: "Avísame a las 5pm",
      source_conversation: source_conversation,
      now: now
    )

    expect { 2.times { scheduler.call } }.to change(ParticipantReminder, :count).by(1)
  end

  it "rejects reminders during quiet hours" do
    result = described_class.new(
      participant: participant,
      text: "Avísame a las 11pm",
      source_conversation: source_conversation,
      now: now
    ).call

    expect(result).not_to be_scheduled
    expect(result.reason).to eq(:quiet_hours)
  end

  it "enforces active reminder limits" do
    create_list(:participant_reminder, 3, participant: participant)

    result = described_class.new(
      participant: participant,
      text: "Avísame a las 5pm",
      source_conversation: source_conversation,
      now: now
    ).call

    expect(result).not_to be_scheduled
    expect(result.reason).to eq(:too_many_active)
  end
end
