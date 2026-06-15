# frozen_string_literal: true

require "rails_helper"

RSpec.describe MorningWakeForParticipantJob, type: :job do
  let(:tz) { "America/Santiago" }
  let(:program) { create(:program, total_days: 14) }
  let(:participant) { create(:participant, program: program, current_day: 1, timezone: tz) }
  let!(:day_content) do
    create(
      :day_content,
      program: program,
      day_number: 1,
      title: "Observar sin juzgar",
      checkin_questions: "1. ¿Qué notaste?\n2. ¿Qué eliges?"
    )
  end

  before do
    Setting.set("missed_checkin_reminder_text", "Cierra el check-in pendiente antes de seguir.")
    allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.REMINDER")
    )
    create(
      :conversation,
      participant: participant,
      role: :assistant,
      moment: :checkin_question,
      day_number: 1,
      sent_at: Time.find_zone(tz).local(2026, 6, 14, 20)
    )
  end

  it "sends a pending check-in reminder instead of the normal morning wake" do
    participant.update!(pending_checkin_at: Time.find_zone(tz).local(2026, 6, 14, 20))
    create(:conversation, participant: participant, role: :user, moment: :free_user, created_at: Time.find_zone(tz).local(2026, 6, 14, 12))

    expect_any_instance_of(Openai::MorningMessageGenerator).not_to receive(:call)
    expect {
      travel_to Time.find_zone(tz).local(2026, 6, 15, 8) do
        described_class.new.perform(participant.id)
      end
    }.not_to have_enqueued_job(SendIaretoJob)

    reminder = participant.conversations.kept.find_by(moment: :checkin_reminder)
    expect(reminder.body).to include("Cierra el check-in pendiente")
    expect(reminder.body).to include("Check-in del día 1")
    expect(participant.conversations.kept.where(moment: :morning_wake)).to be_empty
  end

  it "uses the approved check-in template when the free-form window is closed" do
    participant.update!(pending_checkin_at: Time.find_zone(tz).local(2026, 6, 14, 20))

    sent_templates = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_dispatcher, args|
      sent_templates << args
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end

    travel_to Time.find_zone(tz).local(2026, 6, 15, 8) do
      described_class.new.perform(participant.id)
    end

    expect(sent_templates.first[:template_name]).to eq("checkin_dia_01")
    expect(sent_templates.first[:body_preview]).to include("Cierra el check-in pendiente")
  end

  it "is idempotent for the reminder on the same local day" do
    participant.update!(pending_checkin_at: Time.find_zone(tz).local(2026, 6, 14, 20))
    create(:conversation, participant: participant, role: :user, moment: :free_user, created_at: Time.find_zone(tz).local(2026, 6, 14, 12))

    travel_to Time.find_zone(tz).local(2026, 6, 15, 8) do
      2.times { described_class.new.perform(participant.id) }
    end

    expect(participant.conversations.kept.where(moment: :checkin_reminder).count).to eq(1)
  end
end
