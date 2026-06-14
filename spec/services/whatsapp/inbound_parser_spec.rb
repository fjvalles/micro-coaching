require "rails_helper"

RSpec.describe Whatsapp::InboundParser do
  let(:text_payload) do
    {
      "entry" => [{
        "changes" => [{
          "value" => {
            "messages" => [{
              "from" => "5215551234567",
              "id" => "wamid.test1",
              "timestamp" => "1700000000",
              "type" => "text",
              "text" => { "body" => "Hola" }
            }]
          }
        }]
      }]
    }
  end

  let(:status_payload) do
    {
      "entry" => [{
        "changes" => [{
          "value" => {
            "statuses" => [{
              "id" => "wamid.test1",
              "status" => "delivered",
              "timestamp" => "1700000001",
              "recipient_id" => "5215551234567"
            }]
          }
        }]
      }]
    }
  end

  it "parses text messages" do
    result = described_class.parse(text_payload)
    expect(result[:messages].size).to eq(1)
    expect(result[:messages].first.text).to eq("Hola")
    expect(result[:messages].first.from).to eq("5215551234567")
    expect(result[:messages].first.wamid).to eq("wamid.test1")
  end

  it "parses status updates" do
    result = described_class.parse(status_payload)
    expect(result[:statuses].size).to eq(1)
    expect(result[:statuses].first.status).to eq("delivered")
  end

  it "handles voice (media_id capture)" do
    payload = {
      "entry" => [{ "changes" => [{ "value" => { "messages" => [
        { "from" => "1", "id" => "wamid.v", "timestamp" => "1", "type" => "voice", "voice" => { "id" => "media-123" } }
      ] } }] }]
    }
    result = described_class.parse(payload)
    expect(result[:messages].first.media_id).to eq("media-123")
    expect(result[:messages].first.text).to be_nil
  end

  it "captures the WhatsApp profile name from contacts" do
    payload = {
      "entry" => [{ "changes" => [{ "value" => {
        "contacts" => [{ "wa_id" => "5215551234567", "profile" => { "name" => "Ana Pérez" } }],
        "messages" => [{ "from" => "5215551234567", "id" => "wamid.n", "timestamp" => "1", "type" => "text", "text" => { "body" => "Hola" } }]
      } }] }]
    }
    msg = described_class.parse(payload)[:messages].first
    expect(msg.profile_name).to eq("Ana Pérez")
  end

  it "leaves profile_name nil when no contact matches" do
    expect(described_class.parse(text_payload)[:messages].first.profile_name).to be_nil
  end

  it "handles malformed payload" do
    expect(described_class.parse("not json")).to eq(messages: [], statuses: [])
  end
end
