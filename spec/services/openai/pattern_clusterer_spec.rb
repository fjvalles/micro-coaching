require "rails_helper"

RSpec.describe Openai::PatternClusterer do
  let(:program) { create(:program) }
  let(:see_day)    { create(:day_content, program: program, day_number: 1, phase: :see) }
  let(:choose_day) { create(:day_content, program: program, day_number: 6, phase: :choose) }
  let(:p1) { create(:participant, program: program, current_day: 1) }
  let(:p2) { create(:participant, program: program, current_day: 6) }

  before do
    see_day; choose_day
    create(:daily_report, participant: p1, day_number: 1, ai_key_pattern: "reactivo ante criticas")
    create(:daily_report, participant: p2, day_number: 6, ai_key_pattern: "pausa antes de responder")
  end

  let(:fake_json) do
    {
      "clusters" => [
        {
          "theme" => "Reactividad emocional",
          "frequency" => 1,
          "sample_phrases" => [ "reactivo ante criticas" ],
          "report_indices" => [ 0 ]
        },
        {
          "theme" => "Pausa intencional",
          "frequency" => 1,
          "sample_phrases" => [ "pausa antes de responder" ],
          "report_indices" => [ 1 ]
        }
      ]
    }.to_json
  end

  let(:fake_response) do
    Openai::Client::Result.new(
      content: fake_json,
      tokens_input: 100, tokens_output: 50,
      model: "gpt-4.1-mini", latency_ms: 120
    )
  end

  let(:fake_client) { instance_double(Openai::Client) }

  before { allow(fake_client).to receive(:chat).and_return(fake_response) }

  it "returns clusters enriched with phase_distribution and daily_report_ids" do
    result = described_class.new(program: program, client: fake_client).call

    expect(result.total_reports_analyzed).to eq(2)
    expect(result.clusters.size).to eq(2)
    expect(result.clusters.first).to include(
      "theme" => "Reactividad emocional",
      "sample_phrases" => [ "reactivo ante criticas" ]
    )
    phases = result.clusters.flat_map { |c| c["phase_distribution"].keys }
    expect(phases).to include("see", "choose")
    expect(result.clusters.first["daily_report_ids"]).to all(be_a(String))
  end

  it "logs the execution via PromptLogger" do
    expect(Openai::PromptLogger).to receive(:record).with(
      hash_including(key: described_class::SYSTEM_KEY, program: program, moment: "methodology")
    )
    described_class.new(program: program, client: fake_client).call
  end

  it "returns empty when no reports" do
    DailyReport.delete_all
    result = described_class.new(program: program, client: fake_client).call
    expect(result.clusters).to eq([])
    expect(result.total_reports_analyzed).to eq(0)
    expect(fake_client).not_to have_received(:chat)
  end

  it "handles bad JSON by returning empty clusters" do
    bad = Openai::Client::Result.new(content: "not json", tokens_input: 1, tokens_output: 1, model: "x", latency_ms: 1)
    allow(fake_client).to receive(:chat).and_return(bad)
    result = described_class.new(program: program, client: fake_client).call
    expect(result.clusters).to eq([])
  end
end
