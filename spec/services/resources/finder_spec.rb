require "rails_helper"

RSpec.describe Resources::Finder do
  let(:client) { instance_double(Openai::Client) }

  it "persists only URLs present in search citations" do
    response = Openai::Client::Result.new(
      content: {
        candidates: [
          { title: "Citado", url: "https://example.com/citado", snippet: "ok" },
          { title: "Inventado", url: "https://example.com/inventado", snippet: "no" }
        ]
      }.to_json,
      annotations: [
        { "url_citation" => { "url" => "https://example.com/citado" } }
      ],
      tokens_input: 10,
      tokens_output: 10,
      model: "gpt-4o-search-preview",
      latency_ms: 10
    )
    allow(client).to receive(:chat).and_return(response)

    result = described_class.new(topic: "gestión del foco", kind: "article", client: client).call

    expect(result).to be_ok
    expect(result.resources.map(&:url)).to contain_exactly("https://example.com/citado")
  end
end
