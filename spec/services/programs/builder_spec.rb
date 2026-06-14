require "rails_helper"

RSpec.describe Programs::Builder do
  let(:spec) do
    {
      "name" => "Reset de mañanas", "manifesto" => "Vas a recuperar tus mañanas.",
      "total_days" => 3,
      "days" => [
        { "day_number" => 1, "phase" => "see", "title" => "Observar", "morning_template" => "Buen día",
          "iareto_text" => "Reto 1", "checkin_questions" => "¿Cómo te fue?", "ai_system_prompt" => "Refuerza" },
        { "day_number" => 2, "phase" => "choose", "title" => "Elegir", "morning_template" => "Hola",
          "iareto_text" => "Reto 2", "checkin_questions" => "¿Y hoy?", "ai_system_prompt" => "Acompaña" },
        { "day_number" => 3, "phase" => "anchor", "title" => "Anclar", "morning_template" => "Día 3",
          "iareto_text" => "Reto 3", "checkin_questions" => "¿Lograste?", "ai_system_prompt" => "Consolida" }
      ]
    }
  end

  it "creates an inactive template program with its day contents" do
    result = described_class.new(spec: spec).call

    expect(result).to be_ok
    program = result.program
    expect(program).to be_persisted
    expect(program.template).to be(true)
    expect(program.generated).to be(true)
    expect(program.active).to be(false)
    expect(program.total_days).to eq(3)
    expect(program.day_contents.count).to eq(3)
    expect(program.day_contents.ordered.map(&:phase)).to eq(%w[see choose anchor])
  end

  it "generates a format-valid, unique slug even on name collision" do
    create(:program, slug: "reset-de-mananas")
    result = described_class.new(spec: spec).call

    expect(result.program.slug).to match(/\A[a-z0-9\-]+\z/)
    expect(result.program.slug).not_to eq("reset-de-mananas")
  end

  it "rolls back the whole program when a day content is invalid" do
    spec["days"][1]["phase"] = "bogus"

    expect { described_class.new(spec: spec).call }
      .to change(Program, :count).by(0).and change(DayContent, :count).by(0)
  end

  it "returns an error result when the spec has no days" do
    result = described_class.new(spec: { "name" => "x", "total_days" => 0, "days" => [] }).call
    expect(result).not_to be_ok
    expect(result.error).to be_present
  end
end
