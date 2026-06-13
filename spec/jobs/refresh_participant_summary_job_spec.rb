require "rails_helper"

RSpec.describe RefreshParticipantSummaryJob do
  let(:participant) { create(:participant) }

  it "updates the rolling summary when enabled" do
    result = Openai::ParticipantSummarizer::Result.new(summary: "memoria nueva", prompt_used: "p",
                                                       tokens_input: 1, tokens_output: 1, model: "m")
    allow_any_instance_of(Openai::ParticipantSummarizer).to receive(:call).and_return(result)

    described_class.new.perform(participant.id)

    participant.reload
    expect(participant.ai_summary).to eq("memoria nueva")
    expect(participant.ai_summary_updated_at).to be_present
  end

  it "is a no-op when the kill-switch is off" do
    allow(Setting).to receive(:fetch).and_call_original
    allow(Setting).to receive(:fetch).with("participant_summary_enabled").and_return(false)
    expect_any_instance_of(Openai::ParticipantSummarizer).not_to receive(:call)

    described_class.new.perform(participant.id)

    expect(participant.reload.ai_summary).to be_nil
  end

  it "does not overwrite when the model returns blank" do
    result = Openai::ParticipantSummarizer::Result.new(summary: "", prompt_used: "p",
                                                       tokens_input: 0, tokens_output: 0, model: "m")
    allow_any_instance_of(Openai::ParticipantSummarizer).to receive(:call).and_return(result)

    described_class.new.perform(participant.id)

    expect(participant.reload.ai_summary).to be_nil
  end
end
