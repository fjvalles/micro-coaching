require "rails_helper"

RSpec.describe Methodology::InsightBuilder do
  let(:program)    { create(:program) }
  let!(:see_day)   { create(:day_content, program: program, day_number: 1, phase: :see) }
  let!(:choose_day) { create(:day_content, program: program, day_number: 6, phase: :choose) }
  let!(:anchor_day) { create(:day_content, program: program, day_number: 12, phase: :anchor) }

  let(:fake_clusterer_result) do
    Openai::PatternClusterer::Result.new(
      clusters: [ { "theme" => "Reactividad", "frequency" => 3, "sample_phrases" => [ "x" ], "phase_distribution" => { "see" => 3 }, "daily_report_ids" => [] } ],
      total_reports_analyzed: 3,
      tokens_input: 100, tokens_output: 50, model: "gpt-4.1-mini"
    )
  end
  let(:fake_clusterer) { instance_double(Openai::PatternClusterer, call: fake_clusterer_result) }

  def build_data
    p1 = create(:participant, program: program, current_day: 1, status: :active)
    p2 = create(:participant, program: program, current_day: 6, status: :active)
    p3 = create(:participant, program: program, current_day: 12, status: :completed)

    # Outgoing check-in + inbound response for p1
    create(:conversation, participant: p1, moment: :checkin_question, role: :assistant, day_number: 1, body: "?")
    create(:conversation, participant: p1, moment: :checkin_response, role: :user, day_number: 1, body: "Hoy reaccione mal en una reunion")

    # Stuck pattern: p2 repeats same pattern 3 days
    3.times do |i|
      create(:daily_report, participant: p2, day_number: 4 + i, ai_key_pattern: "evitar conflicto")
    end

    p1
  end

  before { build_data }

  it "persists a row for every supported scope" do
    expect {
      described_class.new(program: program, clusterer: fake_clusterer).call
    }.to change(MethodologyInsight, :count).by(MethodologyInsight::SCOPES.size)
  end

  it "phase_kpi payload exposes the three phases" do
    described_class.new(program: program, clusterer: fake_clusterer).call
    insight = MethodologyInsight.latest_for("phase_kpi", program: program)
    expect(insight.payload["phases"].keys).to contain_exactly("see", "choose", "anchor")
    expect(insight.payload.dig("phases", "see", "response_rate")).to be >= 0
  end

  it "stuck_pattern detects repeated key patterns" do
    described_class.new(program: program, clusterer: fake_clusterer).call
    insight = MethodologyInsight.latest_for("stuck_pattern", program: program)
    stuck = insight.payload["participants"]
    expect(stuck.size).to eq(1)
    expect(stuck.first["repeated_pattern"]).to eq("evitar conflicto")
    expect(stuck.first["days"].sort).to eq([ 4, 5, 6 ])
  end

  it "key_pattern_cluster persists clusterer output" do
    described_class.new(program: program, clusterer: fake_clusterer).call
    insight = MethodologyInsight.latest_for("key_pattern_cluster", program: program)
    expect(insight.payload["clusters"].first["theme"]).to eq("Reactividad")
    expect(insight.payload["total_reports_analyzed"]).to eq(3)
  end

  it "is idempotent across runs (each run creates a fresh snapshot)" do
    described_class.new(program: program, clusterer: fake_clusterer).call
    described_class.new(program: program, clusterer: fake_clusterer).call
    # 2 runs × 6 scopes = 12 rows
    expect(MethodologyInsight.count).to eq(MethodologyInsight::SCOPES.size * 2)
    latest_phase = MethodologyInsight.latest_for("phase_kpi", program: program)
    expect(latest_phase).to eq(MethodologyInsight.for_scope("phase_kpi").recent.first)
  end
end
