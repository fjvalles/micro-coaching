require "rails_helper"

RSpec.describe Openai::GuardrailProposer do
  let(:quality_result) do
    Conversations::QualityScorer::Result.new(
      score: 60,
      subscores: { compound_questions: 20 },
      examples: [ { type: "compound_questions", body: "¿Esto o aquello y qué pasa?" } ],
      sample_size: 1
    )
  end

  it "returns a parsed guardrail proposal" do
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: {
          findings: { weaknesses: [ "preguntas compuestas" ] },
          proposed_guardrails: "#{Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS}\n- Haz una sola pregunta y respeta la autonomía.",
          rationale: "Reduce carga cognitiva.",
          change_kind: "append_bullet"
        }.to_json,
        tokens_input: 10,
        tokens_output: 20,
        model: "gpt-5-mini",
        latency_ms: 1
      )
    )

    result = described_class.new(
      current_guardrails: Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS,
      quality_result: quality_result,
      client: client
    ).call

    expect(result.change_kind).to eq("append_bullet")
    expect(result.proposed_guardrails).to include("Haz una sola pregunta")
    expect(result.tokens_input).to eq(10)
  end

  it "falls back safely on invalid JSON" do
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(content: "no json", tokens_input: 1, tokens_output: 1, model: "gpt-5-mini", latency_ms: 1)
    )

    result = described_class.new(
      current_guardrails: "actual",
      quality_result: quality_result,
      client: client
    ).call

    expect(result.change_kind).to eq("no_change")
    expect(result.proposed_guardrails).to eq("actual")
  end
end
