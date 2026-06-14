require "rails_helper"

RSpec.describe Guardrails::Validator do
  let(:current) { Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS }

  it "accepts a small anchored append" do
    proposed = "#{current}\n- Si aparece cansancio, haz una sola pregunta y respeta la autonomía."

    result = described_class.new(current_guardrails: current, proposed_guardrails: proposed).call

    expect(result).to be_valid
  end

  it "rejects URLs and PII" do
    proposed = "#{current}\n- Escribe a https://x.test o +56912345678."

    result = described_class.new(current_guardrails: current, proposed_guardrails: proposed).call

    expect(result).not_to be_valid
    expect(result.errors).to include("no puede incluir URLs", "no puede incluir teléfonos")
  end

  it "rejects candidates without required anchors" do
    result = described_class.new(current_guardrails: current, proposed_guardrails: "- Responde largo.").call

    expect(result).not_to be_valid
    expect(result.errors).to include("debe conservar la regla de una sola pregunta")
  end
end
