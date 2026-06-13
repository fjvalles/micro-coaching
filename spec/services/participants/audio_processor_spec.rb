require "rails_helper"

RSpec.describe Participants::AudioProcessor do
  let(:participant) { create(:participant) }
  let(:conversation) do
    Conversation.create!(
      participant: participant, day_number: 1, moment: :free_user, role: :user, body: ""
    )
  end

  before do
    Rails.cache.clear
    Setting.set("audio_max_duration_seconds", 180)
  end

  let(:media_result) do
    Whatsapp::MediaFetcher::Result.new(
      bytes: "RAW", mime_type: "audio/ogg", byte_size: 3,
      sha256: "abc", filename: "wa_audio.ogg"
    )
  end

  it "transcribes, analyzes and persists" do
    allow_any_instance_of(Whatsapp::MediaFetcher).to receive(:call).and_return(media_result)
    transcription_result = Openai::AudioTranscriber::Result.new(
      text: "hola desde audio", language: "es", duration: 4.0, model: "m"
    )
    expect(Openai::AudioTranscriber).to receive(:new).with(
      bytes: "RAW",
      filename: "wa_audio.ogg",
      mime_type: "audio/ogg",
      participant: participant,
      conversation: conversation
    ).and_return(instance_double(Openai::AudioTranscriber, call: transcription_result))
    voice_result = Openai::VoiceAnalyzer::Result.new(
      analysis: { "tone" => "cálido", "primary_emotion" => "calma" },
      prompt_used: "p", tokens_input: 10, tokens_output: 5, model: "gpt-4o-audio"
    )
    expect(Openai::VoiceAnalyzer).to receive(:new).with(
      bytes: "RAW",
      mime_type: "audio/ogg",
      participant: participant,
      conversation: conversation
    ).and_return(instance_double(Openai::VoiceAnalyzer, call: voice_result))

    result = described_class.new(conversation: conversation, media_id: "MID").call

    expect(result.transcription).to eq("hola desde audio")
    expect(result.voice_analysis["tone"]).to eq("cálido")

    conversation.reload
    expect(conversation.transcription).to eq("hola desde audio")
    expect(conversation.body).to eq("hola desde audio")
    expect(conversation.media_id).to eq("MID")
    expect(conversation.audio_duration_seconds).to eq(4)
    expect(conversation.voice_analysis["primary_emotion"]).to eq("calma")
  end

  it "flags too_long when duration exceeds setting" do
    Setting.set("audio_max_duration_seconds", 10)
    allow_any_instance_of(Whatsapp::MediaFetcher).to receive(:call).and_return(media_result)
    allow_any_instance_of(Openai::AudioTranscriber).to receive(:call).and_return(
      Openai::AudioTranscriber::Result.new(text: "muy largo", language: "es", duration: 60.0, model: "m")
    )
    expect_any_instance_of(Openai::VoiceAnalyzer).not_to receive(:call)

    result = described_class.new(conversation: conversation, media_id: "MID").call
    expect(result.too_long).to be true
  end

  it "captures error on fetcher failure" do
    allow_any_instance_of(Whatsapp::MediaFetcher).to receive(:call)
      .and_raise(Whatsapp::MediaFetcher::Error, "boom")

    result = described_class.new(conversation: conversation, media_id: "MID").call
    expect(result.error).to eq("boom")
    expect(conversation.reload.error_message).to include("boom")
  end
end
