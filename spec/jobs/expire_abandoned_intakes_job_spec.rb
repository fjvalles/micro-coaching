require "rails_helper"

RSpec.describe ExpireAbandonedIntakesJob, type: :job do
  before { Setting.set("intake_abandonment_days", 3) }

  def intake_participant(**attrs)
    create(:participant, status: :intake, program: nil, current_day: 0,
           intake_state: { "step" => 2, "answers" => {}, "awaiting_open" => false }, **attrs)
  end

  it "reverts a stalled fresh intake back to :pending" do
    p = intake_participant
    p.update_column(:updated_at, 5.days.ago)

    described_class.new.perform

    expect(p.reload.status).to eq("pending")
    expect(p.intake_state).to eq({})
  end

  it "reverts a stalled returning participant back to :completed" do
    p = intake_participant(completed_at: 20.days.ago)
    p.update_column(:updated_at, 5.days.ago)

    described_class.new.perform

    expect(p.reload.status).to eq("completed")
  end

  it "leaves a recently-active intake untouched" do
    p = intake_participant
    p.update_column(:updated_at, 1.hour.ago)

    described_class.new.perform

    expect(p.reload.status).to eq("intake")
  end

  it "leaves a participant awaiting review untouched (generation done, not abandoned)" do
    p = create(:participant, status: :intake, program: nil, current_day: 0,
               intake_state: { "awaiting_review" => true, "template_program_id" => SecureRandom.uuid })
    p.update_column(:updated_at, 5.days.ago)

    described_class.new.perform

    expect(p.reload.status).to eq("intake")
  end

  it "is a no-op when intake_abandonment_days is 0" do
    Setting.set("intake_abandonment_days", 0)
    p = intake_participant
    p.update_column(:updated_at, 30.days.ago)

    described_class.new.perform

    expect(p.reload.status).to eq("intake")
  end
end
