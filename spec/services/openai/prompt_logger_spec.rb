require "rails_helper"

RSpec.describe Openai::PromptLogger do
  let(:program) { create(:program) }
  let(:participant) { create(:participant, program: program) }
  let(:response) { double(content: "out", model: "gpt-4.1-mini", tokens_input: 10, tokens_output: 20) }
  let(:messages) { [ { role: "system", content: "sys body" }, { role: "user", content: "hola" } ] }

  it "creates template + version + execution on first call" do
    expect {
      described_class.record(
        key: "morning_message", name: "Morning",
        system_body: "sys body", messages: messages, response: response,
        program: program, participant: participant, day_number: 3, moment: "morning_wake"
      )
    }.to change(PromptTemplate, :count).by(1)
     .and change(PromptVersion, :count).by(1)
     .and change(PromptExecution, :count).by(1)

    template = PromptTemplate.find_by!(key: "morning_message")
    expect(template.current_version).to eq(1)
    expect(template.current_body).to eq("sys body")
    expect(template.prompt_executions.first.day_number).to eq(3)
  end

  it "bumps version when system body changes between calls" do
    described_class.record(key: "x", name: "X", system_body: "body A", messages: messages, response: response, participant: participant)
    described_class.record(key: "x", name: "X", system_body: "body B", messages: messages, response: response, participant: participant)
    template = PromptTemplate.find_by(key: "x")
    expect(template.current_version).to eq(2)
    expect(template.prompt_versions.pluck(:body)).to contain_exactly("body A", "body B")
  end

  it "reuses latest version when body unchanged" do
    described_class.record(key: "y", name: "Y", system_body: "same", messages: messages, response: response, participant: participant)
    described_class.record(key: "y", name: "Y", system_body: "same", messages: messages, response: response, participant: participant)
    template = PromptTemplate.find_by(key: "y")
    expect(template.current_version).to eq(1)
    expect(template.prompt_executions.count).to eq(2)
  end
end
