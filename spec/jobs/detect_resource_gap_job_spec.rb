require "rails_helper"

RSpec.describe DetectResourceGapJob, type: :job do
  it "does nothing when autodiscovery is disabled" do
    Setting.set("resource_autodiscovery_enabled", false)
    conversation = create(:conversation)

    expect(Resources::GapDetector).not_to receive(:new)

    described_class.new.perform(conversation.id)
  end

  it "finds and verifies a missing resource topic when enabled" do
    Setting.set("resource_autodiscovery_enabled", true)
    conversation = create(:conversation, body: "Necesito entender mejor foco")
    detector = instance_double(Resources::GapDetector)
    detected = Resources::GapDetector::Result.new(needed: true, topic: "foco", kind: "article")
    resource = build(:resource, :pending, topics: [ "foco" ])
    finder = instance_double(Resources::Finder, call: Resources::Finder::Result.new(resources: [ resource ]))
    verifier = instance_double(Resources::Verifier, call: true)

    allow(Resources::GapDetector).to receive(:new)
      .with(participant: conversation.participant, text: conversation.body)
      .and_return(detector)
    allow(detector).to receive(:call).and_return(detected)
    allow(Resources::Finder).to receive(:new).and_return(finder)
    allow(Resources::Verifier).to receive(:new).with(resource: resource, topic: "foco").and_return(verifier)

    described_class.new.perform(conversation.id)

    expect(finder).to have_received(:call)
    expect(verifier).to have_received(:call)
  end
end
