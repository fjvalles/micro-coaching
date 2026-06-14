require "rails_helper"

RSpec.describe RevalidateResourcesJob, type: :job do
  it "revalidates stale resources and archives approved resources that fail" do
    resource = create(:resource, status: :approved, last_verified_at: 40.days.ago)
    verifier = instance_double(Resources::Verifier)

    allow(Resources::Verifier).to receive(:new).with(resource: resource).and_return(verifier)
    allow(verifier).to receive(:call) do
      resource.update!(status: :dead)
      Resources::Verifier::Result.new(resource: resource, ok: false)
    end

    described_class.new.perform

    expect(resource.reload).to be_discarded
  end
end
