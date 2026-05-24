require "rails_helper"

RSpec.describe DayContentsQuery do
  let(:program_a) { create(:program, name: "Alpha") }
  let(:program_b) { create(:program, name: "Beta") }
  let!(:content_a3_choose) { create(:day_content, program: program_a, day_number: 3, phase: :choose, title: "A3", active: true) }
  let!(:content_a4_anchor) { create(:day_content, program: program_a, day_number: 4, phase: :anchor, title: "A4", active: false) }
  let!(:content_b3_choose) { create(:day_content, program: program_b, day_number: 3, phase: :choose, title: "B3", active: true) }

  def build(params, program_context: nil)
    DayContentsQuery.from_params(ActionController::Parameters.new(params), program_context: program_context)
  end

  def titles(scope)
    scope.map { |dc| [ dc.program.name, dc.title ] }.map(&:last)
  end

  it "returns all when no filters" do
    expect(titles(build({}).resolve)).to include("A3", "A4", "B3")
  end

  it "supports multiselect program_ids" do
    result = build({ program_ids: [ program_a.id, program_b.id ] }).resolve
    expect(titles(result)).to contain_exactly("A3", "A4", "B3")
  end

  it "supports multiselect day_numbers, phases, statuses" do
    result = build({ day_numbers: [ 3 ], phases: [ "choose" ], statuses: [ "active" ] }).resolve
    expect(titles(result)).to contain_exactly("A3", "B3")
  end

  it "falls back to legacy singular params" do
    result = build({ program_id: program_a.id, day_number: 4 }).resolve
    expect(titles(result)).to contain_exactly("A4")
  end

  it "scopes to program_context, ignoring program_ids filter" do
    result = build({ program_ids: [ program_b.id ] }, program_context: program_a).resolve
    expect(titles(result)).to contain_exactly("A3", "A4")
  end

  it "exposes normalized filters via to_h" do
    filters = build({ program_ids: [ program_a.id, "" ], q: "  hello  " }).to_h
    expect(filters[:program_ids]).to eq([ program_a.id ])
    expect(filters[:q]).to eq("hello")
  end
end
