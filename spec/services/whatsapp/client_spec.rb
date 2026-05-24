require "rails_helper"

RSpec.describe Whatsapp::Client do
  before do
    ENV["META_PHONE_NUMBER_ID"] = "1234"
    ENV["META_ACCESS_TOKEN"] = "test_token"
    ENV["META_API_VERSION"] = "v21.0"
    Rails.cache.clear
    Setting.set("meta_api_version", "v21.0")
    Setting.set("whatsapp_send_enabled", true)
    Setting.set("whatsapp_retry_max", 3)
  end

  let(:url) { "https://graph.facebook.com/v21.0/1234/messages" }

  it "sends a text and parses wamid" do
    stub_request(:post, url)
      .to_return(status: 200, body: { messages: [ { id: "wamid.OK" } ] }.to_json,
                 headers: { "Content-Type" => "application/json" })

    response = described_class.new.send_text(to: "+5215551234567", body: "hola")
    expect(response.success?).to be true
    expect(response.wamid).to eq("wamid.OK")
  end

  it "returns error on 4xx" do
    stub_request(:post, url)
      .to_return(status: 400, body: { error: { message: "bad", code: 42 } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    response = described_class.new.send_text(to: "+5215551234567", body: "hola")
    expect(response.success?).to be false
    expect(response.error).to eq("(#42) bad")
  end

  it "adds guidance when Meta rejects a number outside the allowed list" do
    stub_request(:post, url)
      .to_return(
        status: 400,
        body: { error: { message: "Recipient phone number not in allowed list", code: 131030 } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = described_class.new.send_template(to: "+521", template_name: "despertar_dia_01")

    expect(response.success?).to be false
    expect(response.error).to include("allowed list")
    expect(response.error).to include("Meta test mode")
  end

  it "retries on 500 then succeeds" do
    stub_request(:post, url)
      .to_return({ status: 500, body: "{}" },
                 { status: 200, body: { messages: [ { id: "wamid.RETRY" } ] }.to_json })

    response = described_class.new.send_text(to: "+5215551234567", body: "hola")
    expect(response.success?).to be true
    expect(response.wamid).to eq("wamid.RETRY")
  end

  it "sends template with components" do
    stub_request(:post, url)
      .with(body: hash_including(type: "template"))
      .to_return(status: 200, body: { messages: [ { id: "wamid.T" } ] }.to_json)

    response = described_class.new.send_template(
      to: "+521", template_name: "despertar_dia_01",
      components: [ { type: "body", parameters: [ { type: "text", text: "Ana" } ] } ]
    )
    expect(response.success?).to be true
  end
end
