require "rails_helper"

RSpec.describe Resources::Catalog do
  it "includes only sendable resources for the program scope" do
    program = create(:program)
    included = create(:resource, title: "Foco", topics: [ "atención" ], program: program)
    general = create(:resource, title: "General", topics: [ "energía" ], program: nil)
    create(:resource, :verified, title: "Pendiente", topics: [ "otra" ], program: program)

    text = described_class.new(program: program).call

    expect(text).to include(included.id)
    expect(text).to include(general.id)
    expect(text).not_to include("Pendiente")
  end
end
