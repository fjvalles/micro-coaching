require "rails_helper"

RSpec.describe Openai::ModelRouter do
  before { Rails.cache.clear }

  it "returns the task-specific default model" do
    expect(described_class.for(:checkin_summarizer)).to eq("gpt-5-nano")
    expect(described_class.for(:free_response)).to eq("gpt-5-mini")
  end

  it "allows task-specific settings to override defaults" do
    Setting.set("openai_model_checkin_summarizer", "gpt-4.1-mini")

    expect(described_class.for(:checkin_summarizer)).to eq("gpt-4.1-mini")
  end

  it "falls back to the global model when a task setting is intentionally blank" do
    Setting.set("openai_model_checkin_summarizer", "")
    Setting.set("openai_model", "gpt-4.1-nano")

    expect(described_class.for(:checkin_summarizer)).to eq("gpt-4.1-nano")
  end

  it "uses the global model for unknown tasks" do
    Setting.set("openai_model", "gpt-4o-mini")

    expect(described_class.for(:unknown_task)).to eq("gpt-4o-mini")
  end

  it "falls back safely when no task is provided" do
    Setting.set("openai_model", "")

    expect(described_class.for(nil)).to eq("gpt-4.1-mini")
  end
end
