require "rails_helper"

RSpec.describe "Admin resources", type: :request do
  let(:admin) { create(:admin_user) }

  before { sign_in admin }

  it "lists resources" do
    create(:resource, title: "Respirar")

    get admin_resources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Respirar")
  end

  it "approves and rejects verified resources" do
    resource = create(:resource, :verified)

    patch approve_admin_resource_path(resource)
    expect(response).to redirect_to(admin_resources_path(status: "verified"))
    expect(resource.reload).to be_approved

    patch reject_admin_resource_path(resource)
    expect(resource.reload).to be_rejected
  end

  it "creates a manual resource and runs verification" do
    verifier = instance_double(Resources::Verifier, call: true)
    allow(Resources::Verifier).to receive(:new).and_return(verifier)

    post admin_resources_path, params: {
      resource: {
        title: "Artículo",
        url: "https://example.com/articulo",
        kind: "article",
        description: "Descripción",
        topics_text: "foco, atención"
      }
    }

    resource = Resource.find_by!(url: "https://example.com/articulo")
    expect(response).to redirect_to(admin_resource_path(resource))
    expect(resource.topics).to eq([ "foco", "atención" ])
    expect(verifier).to have_received(:call)
  end

  it "discovers and verifies candidates for admin review" do
    program = create(:program)
    resource = create(:resource, :pending, topics: [ "sueño" ], program: program, source: :admin_search)
    finder = instance_double(Resources::Finder)
    verifier = instance_double(Resources::Verifier)

    allow(Resources::Finder).to receive(:new)
      .with(topic: "sueño", kind: "article", program: program, source: :admin_search)
      .and_return(finder)
    allow(finder).to receive(:call)
      .and_return(Resources::Finder::Result.new(resources: [ resource ]))
    allow(Resources::Verifier).to receive(:new).with(resource: resource, topic: "sueño").and_return(verifier)
    allow(verifier).to receive(:call) do
      resource.update!(status: :verified, last_verified_at: Time.current)
      Resources::Verifier::Result.new(resource: resource, ok: true)
    end

    post discover_admin_resources_path, params: {
      resource_search: {
        topic: "sueño",
        kind: "article",
        program_id: program.id
      }
    }

    expect(response).to redirect_to(admin_resources_path(status: "verified", topic: "sueño"))
    expect(resource.reload).to be_verified
    expect(verifier).to have_received(:call)
  end
end
