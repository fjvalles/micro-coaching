require "rails_helper"

RSpec.describe ProcessIncomingMessageJob, type: :job do
  let(:participant) { create(:participant, phone_e164: "+5215551234567", initial_pattern: "X") }

  def text_payload(from: "5215551234567", text: "Hola")
    {
      "entry" => [ { "changes" => [ { "value" => { "messages" => [
        { "from" => from, "id" => "wamid.#{SecureRandom.hex(4)}", "timestamp" => Time.now.to_i.to_s,
          "type" => "text", "text" => { "body" => text } }
      ] } } ] } ]
    }
  end

  before do
    PendingResponse.delete_all
    DailyReport.delete_all
    Conversation.delete_all
    Participant.delete_all
    UnknownInbound.delete_all
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "tok"
    stub_request(:post, "https://graph.facebook.com/v21.0/1234/messages")
      .to_return(status: 200, body: { messages: [ { id: "wamid.OUT" } ] }.to_json)
  end

  it "creates UnknownInbound record for unregistered phone" do
    expect {
      described_class.new.perform(text_payload(from: "999999"))
    }.to change(UnknownInbound, :count).by(1)

    record = UnknownInbound.last
    expect(record.phone).to eq("+999999")
    expect(record.message_type).to eq("text")
    expect(record.body_preview).to eq("Hola")
    expect(Conversation.count).to eq(0)
  end

  it "does not duplicate UnknownInbound on repeated webhook delivery" do
    payload = text_payload(from: "999999")
    described_class.new.perform(payload)
    expect {
      described_class.new.perform(payload)
    }.not_to change(UnknownInbound, :count)
  end

  it "stores inbound from known participant" do
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "respondido", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant
    described_class.new.perform(text_payload(text: "hola"))
    expect(participant.conversations.where(role: :user).count).to eq(1)
    expect(participant.conversations.where(role: :assistant).count).to eq(1)
  end

  def audio_payload(from: "5215551234567", media_id: "MID-1")
    {
      "entry" => [ { "changes" => [ { "value" => { "messages" => [
        { "from" => from, "id" => "wamid.#{SecureRandom.hex(4)}", "timestamp" => Time.now.to_i.to_s,
          "type" => "audio", "audio" => { "id" => media_id, "mime_type" => "audio/ogg" } }
      ] } } ] } ]
    }
  end

  it "processes audio: transcribes, persists analysis, then dispatches as free response" do
    participant
    allow_any_instance_of(Participants::AudioProcessor).to receive(:call).and_return(
      Participants::AudioProcessor::Result.new(
        transcription: "hola desde audio",
        voice_analysis: { "tone" => "cálido", "primary_emotion" => "calma" }
      )
    )

    expect_any_instance_of(Openai::FreeResponseGenerator).to receive(:call) do |gen|
      msg = gen.instance_variable_get(:@user_message)
      expect(msg).to include("hola desde audio")
      expect(msg).to include("Nota paralingüística")
      expect(msg).to include("cálido")
      Openai::FreeResponseGenerator::Result.new(body: "ok", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    end

    described_class.new.perform(audio_payload)

    inbound = participant.conversations.where(role: :user).first
    expect(inbound.media_id).to eq("MID-1")
  end

  it "falls back to reject_non_text when audio_processing_enabled is false" do
    Setting.set("audio_processing_enabled", false)
    participant
    expect_any_instance_of(Participants::AudioProcessor).not_to receive(:call)
    described_class.new.perform(audio_payload)
    expect(participant.conversations.where(role: :user).count).to eq(0)
  end

  it "captures initial_pattern when missing" do
    participant.update!(initial_pattern: nil)
    create(:conversation, participant: participant, moment: :welcome, role: :assistant)
    allow_any_instance_of(Whatsapp::Client).to receive(:send_text).and_return(
      Whatsapp::Client::Response.new(success?: true, wamid: "wamid.OK")
    )
    described_class.new.perform(text_payload(text: "Procrastinar"))
    expect(participant.reload.initial_pattern).to eq("Procrastinar")
  end

  describe "free message daily cap" do
    before do
      Setting.set("max_free_messages_per_day", 2)
      Setting.set("free_messages_cap_reply_text", "límite alcanzado")
      allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
        Openai::FreeResponseGenerator::Result.new(body: "ai reply", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
      )
    end

    it "replies up to the cap, sends the notice once, then stays silent" do
      participant
      4.times { |i| described_class.new.perform(text_payload(text: "msg #{i}")) }

      bodies = participant.conversations.where(role: :assistant).pluck(:body)
      expect(bodies.count("ai reply")).to eq(2)
      expect(bodies.count("límite alcanzado")).to eq(1)
    end

    it "does not cap when max_free_messages_per_day is 0" do
      Setting.set("max_free_messages_per_day", 0)
      participant
      4.times { |i| described_class.new.perform(text_payload(text: "msg #{i}")) }
      expect(participant.conversations.where(role: :assistant).where(body: "ai reply").count).to eq(4)
    end
  end

  it "reactivates a paused participant on inbound" do
    allow_any_instance_of(Openai::FreeResponseGenerator).to receive(:call).and_return(
      Openai::FreeResponseGenerator::Result.new(body: "ok", prompt_used: "p", tokens_input: 1, tokens_output: 1, model: "m")
    )
    participant.update!(status: :paused)
    described_class.new.perform(text_payload(text: "volví"))
    expect(participant.reload.status).to eq("active")
  end
end
