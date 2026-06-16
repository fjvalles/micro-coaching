# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckinForParticipantJob, type: :job do
  let(:program) { create(:program, total_days: 14) }
  let(:participant) { create(:participant, program: program, current_day: 1) }

  before do
    create(
      :day_content,
      program: program,
      day_number: 1,
      checkin_questions: "1. ¿Qué observaste?\n2. ¿Qué eliges?"
    )
  end

  def stub_dispatcher
    sends = []
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_text) do |_d, args|
      sends << args
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end
    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_template) do |_d, args|
      sends << args
      Outbound::Dispatcher::Result.new(delivered: true, conversation: build(:conversation))
    end
    sends
  end

  it "skips when today's check-in was already delivered (sent_at present)" do
    create(
      :conversation,
      participant: participant,
      moment: :checkin_question,
      role: :assistant,
      day_number: 1,
      sent_at: Time.current
    )

    sends = stub_dispatcher
    described_class.new.perform(participant.id)

    expect(sends).to be_empty
  end

  it "re-sends when the prior check-in row is a failed send (sent_at nil)" do
    create(
      :conversation,
      participant: participant,
      moment: :checkin_question,
      role: :assistant,
      day_number: 1,
      sent_at: nil,
      error_message: "boom"
    )

    sends = stub_dispatcher
    described_class.new.perform(participant.id)

    expect(sends.size).to eq(1)
  end

  it "does not mark pending_checkin_at when Meta rejects the check-in send" do
    participant.conversations.delete_all

    allow_any_instance_of(Outbound::Dispatcher).to receive(:send_text).and_return(
      Outbound::Dispatcher::Result.new(delivered: false, conversation: build(:conversation, sent_at: nil))
    )

    described_class.new.perform(participant.id)

    expect(participant.reload.pending_checkin_at).to be_nil
  end
end
