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
end
