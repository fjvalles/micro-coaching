require "rails_helper"

RSpec.describe Programs::Approver do
  let(:template) do
    create(:program, template: true, generated: true, active: false, total_days: 3).tap do |p|
      create(:day_content, program: p, day_number: 1, phase: :see)
      create(:day_content, program: p, day_number: 2, phase: :choose)
      create(:day_content, program: p, day_number: 3, phase: :anchor)
    end
  end
  let(:participant) do
    create(:participant, status: :intake, program: nil, current_day: 0,
                         initial_pattern: nil,
                         intake_state: { "step" => 7, "answers" => { "pattern" => "reviso el celular al despertar" } })
  end

  it "clones the template into a live program and activates the participant" do
    clone = described_class.new(participant: participant, template: template).call

    expect(clone.template).to be(false)
    expect(clone.generated).to be(true)
    expect(clone.active).to be(true)
    expect(clone.day_contents.count).to eq(3)
    expect(clone.id).not_to eq(template.id)

    participant.reload
    expect(participant.program).to eq(clone)
    expect(participant).to be_active
    expect(participant.current_day).to eq(1)
    expect(participant.initial_pattern).to eq("reviso el celular al despertar")
    expect(participant.intake_awaiting_review?).to be(false)
  end

  it "fires the welcome job exactly once via the activator" do
    expect { described_class.new(participant: participant, template: template).call }
      .to have_enqueued_job(SendWelcomeJob).with(participant.id)
  end

  it "is idempotent for an already-active participant" do
    participant.update!(status: :active, program: create(:program), current_day: 1)

    expect { described_class.new(participant: participant, template: template).call }
      .not_to change { participant.reload.program_id }
  end

  context "when the participant is returning from a prior cycle (paid Nivel 2)" do
    let(:nivel1) { create(:program, total_days: 3) }
    let(:participant) do
      create(:participant, status: :intake, program: nivel1, current_day: 0,
                           completed_at: Time.current, ai_summary: "memoria del Nivel 1",
                           intake_state: { "step" => 7, "answers" => { "pattern" => "x" } }).tap do |p|
        p.enrollments.create!(program: nivel1, cycle_number: 1, status: :completed, started_at: 14.days.ago)
      end
    end

    it "re-enrolls into a new cycle instead of first-activating" do
      clone = described_class.new(participant: participant, template: template).call

      participant.reload
      expect(participant).to be_active
      expect(participant.program).to eq(clone)
      expect(participant.current_day).to eq(1)
      # ReEnroller resets the rolling AI memory for the new cycle.
      expect(participant.ai_summary).to be_nil
      # The prior cycle stays, a new one opens.
      expect(participant.enrollments.where(program: clone, status: :active)).to exist
      expect(participant.enrollments.count).to eq(2)
    end
  end
end
