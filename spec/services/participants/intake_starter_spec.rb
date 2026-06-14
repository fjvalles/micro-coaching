require "rails_helper"

RSpec.describe Participants::IntakeStarter do
  before { Setting.set("program_intake_enabled", true) }

  it "is disabled when the kill-switch is off" do
    Setting.set("program_intake_enabled", false)
    participant = create(:participant, status: :pending)

    result = described_class.new(participant).call

    expect(result).not_to be_ok
    expect(result.reason).to eq(:disabled)
  end

  it "starts intake for a pending participant" do
    participant = create(:participant, status: :pending, program: nil, current_day: 0)

    expect { described_class.new(participant).call }
      .to have_enqueued_job(SendIntakeOpenerJob).with(participant.id)

    participant.reload
    expect(participant).to be_intake
    expect(participant.intake_state).to include("step" => 0, "awaiting_open" => true)
  end

  it "lets a completed participant re-enter intake to design their paid Nivel 2" do
    participant = create(:participant, status: :completed, completed_at: Time.current)

    result = described_class.new(participant).call

    expect(result).to be_ok
    participant.reload
    expect(participant).to be_intake
    # current_day reset so the :intake status passes the program-range validation.
    expect(participant.current_day).to eq(0)
  end

  it "refuses a participant who is actively running a program" do
    participant = create(:participant, status: :active)

    result = described_class.new(participant).call

    expect(result).not_to be_ok
    expect(result.reason).to eq(:already_active)
  end
end
