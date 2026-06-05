require "rails_helper"

RSpec.describe Skills::CoachingHint do
  let(:participant) { create(:participant) }
  let(:skill) do
    create(:skill, name: "Escucha activa", definition: "Atención plena.",
                   practices: [ "Suspender el juicio." ], gestures: [ "No interrumpir." ],
                   exercises: [ "Tres minutos sin interrumpir." ])
  end

  def detect(s, times)
    times.times { create(:skill_detection, participant: participant, skill: s) }
  end

  it "builds a hint for the most frequently detected skill" do
    other = create(:skill, name: "Coraje")
    detect(skill, 3)
    detect(other, 1)

    hint = described_class.for(participant)
    expect(hint).to include("Escucha activa")
    expect(hint).to include("Suspender el juicio.")
    expect(hint).to include("No interrumpir.")
    expect(hint).not_to include("Coraje")
  end

  it "returns nil when there are no detections" do
    expect(described_class.for(participant)).to be_nil
  end

  it "returns nil when the feature is disabled" do
    detect(skill, 2)
    allow(Setting).to receive(:fetch).and_call_original
    allow(Setting).to receive(:fetch).with("skill_coaching_injection_enabled").and_return(false)
    expect(described_class.for(participant)).to be_nil
  end

  it "ignores detections outside the window" do
    travel_to(40.days.ago) { detect(skill, 3) }
    expect(described_class.for(participant)).to be_nil
  end
end
