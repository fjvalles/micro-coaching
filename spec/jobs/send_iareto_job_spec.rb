# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendIaretoJob, type: :job do
  let(:tz) { "America/Santiago" }
  let(:program) { create(:program, total_days: 14) }
  let(:participant) { create(:participant, program: program, current_day: 1, timezone: tz) }

  before do
    create(:day_content, program: program, day_number: 1, iareto_text: "Haz el primer paso.")
    create(
      :conversation,
      participant: participant,
      role: :assistant,
      moment: :checkin_question,
      day_number: 1,
      sent_at: Time.find_zone(tz).local(2026, 6, 14, 20)
    )
  end

  it "does not send IAReto while yesterday's check-in is still pending" do
    participant.update!(pending_checkin_at: Time.find_zone(tz).local(2026, 6, 14, 20))

    expect_any_instance_of(Outbound::Dispatcher).not_to receive(:send_text)
    expect_any_instance_of(Outbound::Dispatcher).not_to receive(:send_template)

    travel_to Time.find_zone(tz).local(2026, 6, 15, 8, 30) do
      described_class.new.perform(participant.id)
    end
  end
end
