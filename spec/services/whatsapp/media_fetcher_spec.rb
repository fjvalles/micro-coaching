require "rails_helper"

RSpec.describe Whatsapp::MediaFetcher do
  before do
    ENV["META_ACCESS_TOKEN"] = "tok"
    ENV["META_API_VERSION"] = "v21.0"
    Rails.cache.clear
    Setting.set("meta_api_version", "v21.0")
  end

  let(:media_id) { "MEDIA_123" }

  it "fetches metadata then downloads bytes" do
    stub_request(:get, "https://graph.facebook.com/v21.0/#{media_id}")
      .with(headers: { "Authorization" => "Bearer tok" })
      .to_return(status: 200, body: { url: "https://lookaside.fbsbx.com/whatsapp/abc", mime_type: "audio/ogg" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    stub_request(:get, "https://lookaside.fbsbx.com/whatsapp/abc")
      .with(headers: { "Authorization" => "Bearer tok" })
      .to_return(status: 200, body: "RAWBYTES")

    result = described_class.new(media_id: media_id).call

    expect(result.bytes).to eq("RAWBYTES")
    expect(result.mime_type).to eq("audio/ogg")
    expect(result.byte_size).to eq(8)
    expect(result.sha256).to eq(Digest::SHA256.hexdigest("RAWBYTES"))
    expect(result.filename).to end_with(".ogg")
  end

  it "raises when metadata is missing url" do
    stub_request(:get, "https://graph.facebook.com/v21.0/#{media_id}")
      .to_return(status: 200, body: {}.to_json)

    expect { described_class.new(media_id: media_id).call }.to raise_error(Whatsapp::MediaFetcher::Error)
  end

  it "raises on non-2xx metadata" do
    stub_request(:get, "https://graph.facebook.com/v21.0/#{media_id}")
      .to_return(status: 404, body: "{}")

    expect { described_class.new(media_id: media_id).call }.to raise_error(Whatsapp::MediaFetcher::Error)
  end
end
