require "rails_helper"

RSpec.describe Participants::ManualCheckinAssignment do
  let(:admin) { create(:admin_user, email: "ops@example.com") }
  let(:program) { create(:program, total_days: 14) }
  let(:participant) { create(:participant, program: program, status: :active, current_day: 1, timezone: "America/Santiago") }
  let!(:day_content) do
    create(:day_content, program: program, day_number: 1, title: "Observar", checkin_questions: "1. ¿Qué notaste?")
  end
  let(:tz) { Time.find_zone("America/Santiago") }

  before do
    allow_any_instance_of(Openai::CheckinSummarizer).to receive(:call).and_return(
      Openai::CheckinSummarizer::Result.new(
        summary: "Observó ansiedad y consumo de dulce.",
        key_pattern: "ansiedad nocturna",
        prompt_used: "p",
        tokens_input: 10,
        tokens_output: 5,
        model: "gpt-5-nano"
      )
    )
  end

  it "assigns one or more user responses as check-in and clears the pending state" do
    pending_at = tz.local(2026, 6, 15, 20)
    participant.update!(pending_checkin_at: pending_at)
    create(:conversation, participant: participant, role: :assistant, moment: :checkin_question,
                          day_number: 1, sent_at: pending_at)
    first = create(:conversation, participant: participant, role: :user, moment: :free_user,
                                  day_number: 1, body: "Ayer tuve ansiedad.", created_at: pending_at + 14.hours)
    second = create(:conversation, participant: participant, role: :user, moment: :free_user,
                                   day_number: 1, body: "Comí dos paquetes de galletas.", created_at: pending_at + 15.hours)

    travel_to tz.local(2026, 6, 16, 11) do
      result = described_class.new(
        participant: participant,
        conversation_ids: [ first.id, second.id ],
        admin_user: admin
      ).call

      expect(result).to be_ok
    end

    expect(first.reload).to be_checkin_response
    expect(second.reload).to be_checkin_response
    expect(first.inbound_intent).to eq("checkin_answer")
    expect(participant.reload.pending_checkin_at).to be_nil

    report = DailyReport.last
    expect(report.raw_text).to include("Ayer tuve ansiedad.")
    expect(report.raw_text).to include("Comí dos paquetes")
    expect(report.ai_summary).to eq("Observó ansiedad y consumo de dulce.")
  end

  it "refuses assignment before the pending check-in is overdue" do
    now = tz.local(2026, 6, 15, 20, 30)
    participant.update!(pending_checkin_at: now - 30.minutes)
    create(:conversation, participant: participant, role: :assistant, moment: :checkin_question,
                          day_number: 1, sent_at: now - 30.minutes)
    answer = create(:conversation, participant: participant, role: :user, moment: :free_user,
                                   day_number: 1, body: "Respondí.", created_at: now)

    travel_to now do
      result = described_class.new(participant: participant, conversation_ids: [ answer.id ], admin_user: admin).call
      expect(result.reason).to eq(:not_overdue)
    end

    expect(answer.reload).to be_free_user
    expect(DailyReport.count).to eq(0)
  end

  it "refuses conversations that are not eligible for the pending check-in" do
    pending_at = tz.local(2026, 6, 15, 20)
    participant.update!(pending_checkin_at: pending_at)
    create(:conversation, participant: participant, role: :assistant, moment: :checkin_question,
                          day_number: 1, sent_at: pending_at)
    old_answer = create(:conversation, participant: participant, role: :user, moment: :free_user,
                                       day_number: 1, body: "Antes.", created_at: pending_at - 1.hour)

    travel_to tz.local(2026, 6, 16, 11) do
      result = described_class.new(participant: participant, conversation_ids: [ old_answer.id ], admin_user: admin).call
      expect(result.reason).to eq(:invalid_selection)
    end
  end
end
