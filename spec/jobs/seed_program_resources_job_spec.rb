require "rails_helper"

RSpec.describe SeedProgramResourcesJob, type: :job do
  it "does nothing while resource catalog and autodiscovery are disabled" do
    Setting.set("resource_catalog_enabled", false)
    Setting.set("resource_autodiscovery_enabled", false)

    expect(Resources::Finder).not_to receive(:new)

    described_class.new.perform(create(:program).id, [ "foco" ])
  end

  it "finds and verifies resources for unique topics when enabled" do
    Setting.set("resource_catalog_enabled", true)
    program = create(:program)
    resource = create(:resource, :pending, program: program)
    finder = instance_double(Resources::Finder)
    verifier = instance_double(Resources::Verifier, call: true)

    allow(Resources::Finder).to receive(:new)
      .with(topic: "foco", kind: "article", program: program, source: :program_seed)
      .and_return(finder)
    allow(finder).to receive(:call).and_return(Resources::Finder::Result.new(resources: [ resource ]))
    allow(Resources::Verifier).to receive(:new).with(resource: resource, topic: "foco").and_return(verifier)

    described_class.new.perform(program.id, [ "foco", "foco" ])

    expect(finder).to have_received(:call).once
    expect(verifier).to have_received(:call).once
  end
end
