require "rails_helper"

RSpec.describe Openai::SkillTagger do
  let(:participant) { create(:participant) }
  let!(:escucha) { create(:skill, slug: "escucha_activa", name: "Escucha activa") }
  let!(:coraje)  { create(:skill, slug: "coraje", name: "Coraje") }

  let(:fake_client) { instance_double(Openai::Client) }
  def response_with(json)
    Openai::Client::Result.new(content: json, tokens_input: 50, tokens_output: 10, model: "gpt-4.1-mini", latency_ms: 80)
  end

  it "returns tags only for slugs present in the catalog" do
    json = { skills: [ { slug: "escucha_activa", confidence: 0.9 }, { slug: "inventada", confidence: 0.8 } ] }.to_json
    allow(fake_client).to receive(:chat).and_return(response_with(json))

    result = described_class.new(participant: participant, text: "no escuché bien a mi equipo", client: fake_client).call

    expect(result.tags.map(&:slug)).to eq([ "escucha_activa" ])
    expect(result.tags.first.confidence).to eq(0.9)
  end

  it "caps at three tags" do
    create(:skill, slug: "vision", name: "Visión")
    create(:skill, slug: "empatia", name: "Empatía")
    slugs = %w[escucha_activa coraje vision empatia]
    json = { skills: slugs.map { |s| { slug: s, confidence: 0.7 } } }.to_json
    allow(fake_client).to receive(:chat).and_return(response_with(json))

    result = described_class.new(participant: participant, text: "varias cosas", client: fake_client).call
    expect(result.tags.size).to eq(3)
  end

  it "returns empty without calling OpenAI when text is blank" do
    expect(fake_client).not_to receive(:chat)
    result = described_class.new(participant: participant, text: "  ", client: fake_client).call
    expect(result.tags).to be_empty
  end

  it "returns empty without calling OpenAI when the catalog is empty" do
    Skill.delete_all
    expect(fake_client).not_to receive(:chat)
    result = described_class.new(participant: participant, text: "algo", client: fake_client).call
    expect(result.tags).to be_empty
  end

  it "falls back to empty on unparseable JSON" do
    allow(fake_client).to receive(:chat).and_return(response_with("not json"))
    result = described_class.new(participant: participant, text: "algo", client: fake_client).call
    expect(result.tags).to be_empty
  end
end
