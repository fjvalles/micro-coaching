require "rails_helper"

RSpec.describe ResponseMode do
  let(:program) { create(:program) }
  let(:participant) { create(:participant, program: program) }

  before { Setting.set("response_mode", "auto") }

  it "falls back to global default" do
    expect(described_class.for(participant)).to eq("auto")
  end

  it "uses program override when participant blank" do
    program.update!(response_mode: "approve")
    expect(described_class.for(participant)).to eq("approve")
  end

  it "participant override wins" do
    program.update!(response_mode: "approve")
    participant.update!(response_mode: "manual")
    expect(described_class.for(participant)).to eq("manual")
  end

  it "ignores garbage values" do
    participant.update_column(:response_mode, "lolwut")
    expect(described_class.for(participant)).to eq("auto")
  end

  it "uses global Setting when neither program nor participant set" do
    Setting.set("response_mode", "suggest")
    expect(described_class.for(participant)).to eq("suggest")
  end
end
