require "rails_helper"

RSpec.describe Whatsapp::SignatureVerifier do
  let(:secret) { "test_secret" }
  let(:payload) { '{"hello":"world"}' }
  let(:signature) { "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload) }

  before { ENV["META_APP_SECRET"] = secret }

  it "valid signature passes" do
    expect(described_class.valid?(payload: payload, signature: signature)).to be true
  end

  it "invalid signature fails" do
    expect(described_class.valid?(payload: payload, signature: "sha256=deadbeef")).to be false
  end

  it "missing signature fails" do
    expect(described_class.valid?(payload: payload, signature: nil)).to be false
  end

  it "missing secret fails" do
    ENV["META_APP_SECRET"] = ""
    expect(described_class.valid?(payload: payload, signature: signature)).to be false
  end
end
