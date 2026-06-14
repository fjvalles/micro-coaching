require "rails_helper"

RSpec.describe Resources::Verifier do
  let(:client) { instance_double(Openai::Client) }

  before do
    allow(Resolv).to receive(:getaddresses).with("example.com").and_return([ "93.184.216.34" ])
    allow(client).to receive(:chat).and_return(
      Openai::Client::Result.new(
        content: { match: true, reason: "corresponde" }.to_json,
        tokens_input: 5,
        tokens_output: 5,
        model: "gpt-5-nano",
        latency_ms: 5
      )
    )
  end

  it "marks a matching 2xx resource as verified" do
    resource = create(:resource, :pending, url: "https://example.com/foco", topics: [ "foco" ])
    stub_request(:get, "https://example.com/foco")
      .to_return(status: 200, body: "<title>Foco</title><meta name=\"description\" content=\"Atención\">")

    result = described_class.new(resource: resource, client: client).call

    expect(result).to be_ok
    expect(resource.reload).to be_verified
    expect(resource.verification["http_status"]).to eq(200)
  end

  it "approves a matching resource when review is disabled" do
    Setting.set("resource_review_required", false)
    resource = create(:resource, :pending, url: "https://example.com/auto", topics: [ "foco" ])
    stub_request(:get, "https://example.com/auto").to_return(status: 200, body: "<title>Foco</title>")

    described_class.new(resource: resource, client: client).call

    expect(resource.reload).to be_approved
  end

  it "marks a dead resource on 404" do
    resource = create(:resource, :pending, url: "https://example.com/nope", topics: [ "foco" ])
    stub_request(:get, "https://example.com/nope").to_return(status: 404, body: "not found")

    result = described_class.new(resource: resource, client: client).call

    expect(result).not_to be_ok
    expect(resource.reload).to be_dead
  end

  it "blocks private hosts before fetching" do
    allow(Resolv).to receive(:getaddresses).with("localhost").and_return([ "127.0.0.1" ])
    resource = create(:resource, :pending, url: "http://localhost/private", topics: [ "foco" ])

    result = described_class.new(resource: resource, client: client).call

    expect(result).not_to be_ok
    expect(resource.reload).to be_rejected
    expect(WebMock).not_to have_requested(:get, "http://localhost/private")
  end
end
