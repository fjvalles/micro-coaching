require "rails_helper"

RSpec.describe Openai::VoiceAnalyzer do
  before do
    Rails.cache.clear
    Setting.set("openai_voice_analysis_enabled", true)
    Setting.set("openai_voice_analysis_model", "gpt-4o-mini-audio-preview")
    Setting.set("openai_retry_max", 1)
    Setting.set("openai_dry_run_global", false)
  end

  it "skips when disabled" do
    Setting.set("openai_voice_analysis_enabled", false)
    result = described_class.new(bytes: "x", mime_type: "audio/mp3", api_key: "k").call
    expect(result.skipped_reason).to eq("voice_analysis_disabled")
  end

  it "returns dry-run when global kill-switch is on" do
    Setting.set("openai_dry_run_global", true)
    result = described_class.new(bytes: "x", mime_type: "audio/mp3", api_key: "k").call
    expect(result.model).to eq("dry-run")
  end

  it "calls chat with input_audio when mime is mp3 (no ffmpeg needed)" do
    fake_client = instance_double(::OpenAI::Client)
    allow(::OpenAI::Client).to receive(:new).and_return(fake_client)

    expect(fake_client).to receive(:chat) do |parameters:|
      audio_block = parameters[:messages].last[:content].find { |c| c[:type] == "input_audio" }
      expect(audio_block[:input_audio][:format]).to eq("mp3")
      expect(audio_block[:input_audio][:data]).to eq(Base64.strict_encode64("AUDIO"))
      expect(parameters[:response_format]).to eq({ type: "json_object" })
      {
        "choices" => [ { "message" => { "content" => '{"tone":"cálido","primary_emotion":"calma"}' } } ],
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 },
        "model" => "gpt-4o-mini-audio-preview"
      }
    end

    result = described_class.new(bytes: "AUDIO", mime_type: "audio/mpeg", api_key: "k").call
    expect(result.analysis["tone"]).to eq("cálido")
    expect(result.tokens_input).to eq(10)
  end

  it "skips with ffmpeg_unavailable when mime is ogg and ffmpeg is missing" do
    analyzer = described_class.new(bytes: "OGGBYTES", mime_type: "audio/ogg", api_key: "k")
    allow(analyzer).to receive(:system).with("which ffmpeg > /dev/null 2>&1").and_return(false)

    result = analyzer.call
    expect(result.skipped_reason).to eq("ffmpeg_unavailable")
  end
end
