require "rails_helper"

RSpec.describe Openai::ProgramGenerator do
  let(:fake_client) { instance_double(Openai::Client) }
  let(:answers) do
    {
      "goal" => "dejar de postergar", "pattern" => "abro el celular al despertar",
      "obstacle" => "ansiedad", "time" => "20 minutos", "identity" => "alguien enfocado",
      "motivation" => "empiezo un trabajo nuevo", "duration" => "7 días"
    }
  end

  def response_with(content)
    Openai::Client::Result.new(content: content, tokens_input: 200, tokens_output: 800, model: "gpt-5-mini", latency_ms: 500)
  end

  def valid_spec(total: 7)
    {
      name: "Reset de mañanas", manifesto: "Vas a recuperar tus primeras horas.",
      total_days: total,
      days: (1..total).map do |d|
        phase = d <= 2 ? "see" : (d >= total - 1 ? "anchor" : "choose")
        { day_number: d, phase: phase, title: "Día #{d}", morning_template: "Buen día",
          iareto_text: "Reto", checkin_questions: "¿Cómo te fue?", ai_system_prompt: "Refuerza el foco" }
      end
    }
  end

  it "returns a validated spec hash on well-formed JSON" do
    allow(fake_client).to receive(:chat).and_return(response_with(valid_spec.to_json))

    result = described_class.new(answers: answers, client: fake_client).call

    expect(result).to be_ok
    expect(result.spec["total_days"]).to eq(7)
    expect(result.spec["days"].length).to eq(7)
    expect(result.tokens_output).to eq(800)
  end

  it "passes the intake answers into the user prompt" do
    allow(fake_client).to receive(:chat) do |args|
      expect(args[:messages].last[:content]).to include("abro el celular al despertar")
      expect(args[:response_format]).to eq({ type: "json_object" })
      response_with(valid_spec.to_json)
    end

    described_class.new(answers: answers, client: fake_client).call
  end

  it "instructs generated day fragments not to include greetings or signatures" do
    allow(fake_client).to receive(:chat) do |args|
      prompt = args[:messages].first[:content]
      expect(prompt).to include("morning_template, iareto_text y checkin_questions son fragmentos")
      expect(prompt).to include("No incluyas saludo inicial")
      expect(prompt).to include("firma/remitente")
      expect(prompt).to include("Español chileno natural")
      expect(prompt).to include("te late")
      response_with(valid_spec.to_json)
    end

    described_class.new(answers: answers, client: fake_client).call
  end

  it "returns spec: nil on unparseable JSON" do
    allow(fake_client).to receive(:chat).and_return(response_with("not json"))
    result = described_class.new(answers: answers, client: fake_client).call
    expect(result).not_to be_ok
    expect(result.spec).to be_nil
  end

  it "rejects a spec whose days count does not match total_days" do
    broken = valid_spec(total: 7)
    broken[:days] = broken[:days].first(5)
    allow(fake_client).to receive(:chat).and_return(response_with(broken.to_json))

    expect(described_class.new(answers: answers, client: fake_client).call).not_to be_ok
  end

  it "rejects a spec with an invalid phase" do
    broken = valid_spec(total: 5)
    broken[:days].first[:phase] = "wander"
    allow(fake_client).to receive(:chat).and_return(response_with(broken.to_json))

    expect(described_class.new(answers: answers, client: fake_client).call).not_to be_ok
  end

  it "rejects a spec outside the day bounds" do
    allow(fake_client).to receive(:chat).and_return(response_with(valid_spec(total: 2).to_json))
    expect(described_class.new(answers: answers, client: fake_client).call).not_to be_ok
  end
end
