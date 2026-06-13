require "rails_helper"

RSpec.describe Openai::Client do
  before do
    Rails.cache.clear
    Setting.set("openai_dry_run_global", false)
    Setting.set("openai_retry_max", 1)
  end

  it "routes a task to its configured GPT-5 model using compatible chat parameters" do
    fake_http = instance_double(::OpenAI::Client)
    allow(::OpenAI::Client).to receive(:new).and_return(fake_http)

    expect(fake_http).to receive(:chat) do |parameters:|
      expect(parameters[:model]).to eq("gpt-5-mini")
      expect(parameters[:max_completion_tokens]).to eq(123)
      expect(parameters).not_to have_key(:max_tokens)
      expect(parameters).not_to have_key(:temperature)
      {
        "choices" => [ { "message" => { "content" => "ok" } } ],
        "usage" => { "prompt_tokens" => 11, "completion_tokens" => 7 }
      }
    end

    result = described_class.new(api_key: "k").chat(
      messages: [ { role: "user", content: "hola" } ],
      max_tokens: 123,
      temperature: 0.75,
      task: :free_response
    )

    expect(result.content).to eq("ok")
    expect(result.model).to eq("gpt-5-mini")
  end

  it "lets an explicit model override task routing and keeps legacy chat parameters" do
    fake_http = instance_double(::OpenAI::Client)
    allow(::OpenAI::Client).to receive(:new).and_return(fake_http)

    expect(fake_http).to receive(:chat) do |parameters:|
      expect(parameters[:model]).to eq("gpt-4.1-mini")
      expect(parameters[:max_tokens]).to eq(80)
      expect(parameters[:temperature]).to eq(0.3)
      expect(parameters).not_to have_key(:max_completion_tokens)
      {
        "choices" => [ { "message" => { "content" => "json" } } ],
        "usage" => { "prompt_tokens" => 5, "completion_tokens" => 2 }
      }
    end

    result = described_class.new(api_key: "k", model: "gpt-4.1-mini").chat(
      messages: [ { role: "user", content: "hola" } ],
      max_tokens: 80,
      temperature: 0.3,
      task: :checkin_summarizer
    )

    expect(result.model).to eq("gpt-4.1-mini")
  end
end
