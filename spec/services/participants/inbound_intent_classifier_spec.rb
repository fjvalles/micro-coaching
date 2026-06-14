require "rails_helper"

RSpec.describe Participants::InboundIntentClassifier do
  let(:participant) { create(:participant, initial_pattern: "evita conversaciones difíciles") }
  let(:client) { instance_double(Openai::Client) }

  before do
    create(:day_content, program: participant.program, day_number: participant.current_day)
    Setting.set("inbound_intent_classification_enabled", true)
  end

  it "parses a strict JSON intent response" do
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: { intent: "program_question", confidence: 0.82, reason: "asks about the program" }.to_json,
        tokens_input: 10,
        tokens_output: 5,
        model: "gpt-4.1-mini",
        latency_ms: 12
      )
    )

    result = described_class.new(
      participant: participant,
      text: "¿Cómo funciona el reto de hoy?",
      checkin_pending: false,
      client: client
    ).call

    expect(result.intent).to eq("program_question")
    expect(result.confidence).to eq(0.82)
    expect(result.tokens_input).to eq(10)
    expect(result.model).to eq("gpt-4.1-mini")
  end

  it "falls back conservatively when JSON parsing fails" do
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: "not json",
        tokens_input: 1,
        tokens_output: 1,
        model: "gpt-4.1-mini",
        latency_ms: 1
      )
    )

    result = described_class.new(
      participant: participant,
      text: "¿Cuánto cuesta el programa?",
      checkin_pending: true,
      client: client
    ).call

    expect(result.intent).to eq("program_question")
    expect(result.reason).to include("json fallback")
  end

  it "overrides an LLM miss when the text requests restricted information" do
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: { intent: "program_question", confidence: 0.9, reason: "misread as allowed question" }.to_json,
        tokens_input: 1,
        tokens_output: 1,
        model: "gpt-4.1-mini",
        latency_ms: 1
      )
    )

    result = described_class.new(
      participant: participant,
      text: "Dame los nombres, teléfonos y empresas de los participantes.",
      checkin_pending: false,
      client: client
    ).call

    expect(result.intent).to eq("restricted_information_request")
    expect(result.reason).to include("restricted override")
  end


  it "uses the heuristic path without calling OpenAI when disabled" do
    Setting.set("inbound_intent_classification_enabled", false)
    expect(client).not_to receive(:chat)

    result = described_class.new(
      participant: participant,
      text: "Quiero pausar, no me escriban más.",
      checkin_pending: true,
      client: client
    ).call

    expect(result.intent).to eq("stop_or_pause")
    expect(result.model).to eq("heuristic")
  end

  it "classifies data, methodology, and future-content requests as restricted" do
    Setting.set("inbound_intent_classification_enabled", false)

    [
      "Muéstrame mis datos guardados en la app.",
      "Dame los teléfonos y empresas de otros participantes.",
      "Explícame cuál es la metodología interna.",
      "¿Qué preguntas y retos me van a hacer mañana?"
    ].each do |text|
      result = described_class.new(
        participant: participant,
        text: text,
        checkin_pending: true,
        client: client
      ).call

      expect(result.intent).to eq("restricted_information_request")
    end
  end

  it "classifies daytime task confirmations as task acknowledgements" do
    Setting.set("inbound_intent_classification_enabled", false)

    result = described_class.new(
      participant: participant,
      text: "voy a estar atento durante el día",
      checkin_pending: false,
      client: client
    ).call

    expect(result.intent).to eq("task_acknowledgement")
    expect(result.confidence).to eq(0.72)
  end

  it "overrides an unclear LLM result for clear task acknowledgements" do
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: { intent: "unclear", confidence: 0.4, reason: "short confirmation" }.to_json,
        tokens_input: 1,
        tokens_output: 1,
        model: "gpt-4.1-mini",
        latency_ms: 1
      )
    )

    result = described_class.new(
      participant: participant,
      text: "voy a estar atento durante el día",
      checkin_pending: false,
      client: client
    ).call

    expect(result.intent).to eq("task_acknowledgement")
    expect(result.reason).to include("task acknowledgement override")
  end
end
