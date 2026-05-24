require "rails_helper"

RSpec.describe Openai::AudioTranscriber do
  before do
    Rails.cache.clear
    Setting.set("openai_transcription_model", "gpt-4o-mini-transcribe")
    Setting.set("openai_retry_max", 1)
    Setting.set("openai_dry_run_global", false)
  end

  it "returns dry-run when global kill-switch is on" do
    Setting.set("openai_dry_run_global", true)
    result = described_class.new(bytes: "x", filename: "a.ogg", api_key: "k").call
    expect(result.text).to include("dry-run")
    expect(result.model).to eq("dry-run")
  end

  it "calls OpenAI audio.transcribe with a tempfile" do
    fake_client = instance_double(::OpenAI::Client)
    fake_audio  = double("audio")
    allow(::OpenAI::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:audio).and_return(fake_audio)

    expect(fake_audio).to receive(:transcribe) do |parameters:|
      expect(parameters[:model]).to eq("gpt-4o-mini-transcribe")
      expect(parameters[:language]).to eq("es")
      expect(parameters[:file]).to respond_to(:read)
      { "text" => "  hola mundo  ", "language" => "es", "duration" => 4.2 }
    end

    result = described_class.new(bytes: "RAW", filename: "a.ogg", api_key: "k").call
    expect(result.text).to eq("hola mundo")
    expect(result.language).to eq("es")
    expect(result.duration).to eq(4.2)
  end
end
