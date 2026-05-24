require "rails_helper"

RSpec.describe RefreshMethodologyInsightsJob do
  let!(:active_program) { create(:program, active: true) }
  let!(:inactive_program) { create(:program, active: false) }

  it "invokes Methodology::InsightBuilder for each active program plus a global snapshot" do
    expect(Methodology::InsightBuilder).to receive(:call).with(program: active_program)
    expect(Methodology::InsightBuilder).to receive(:call).with(program: nil)
    expect(Methodology::InsightBuilder).not_to receive(:call).with(program: inactive_program)

    described_class.new.perform
  end

  it "scoped run targets a single program" do
    expect(Methodology::InsightBuilder).to receive(:call).with(program: active_program).once

    described_class.new.perform(program_id: active_program.id)
  end
end
