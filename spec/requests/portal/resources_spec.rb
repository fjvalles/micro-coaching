require "rails_helper"

RSpec.describe "Portal::Resources", type: :request do
  let(:participant) { create(:participant, email: "u@e.com") }

  def login!(p)
    get portal_session_path(p.generate_token_for(:portal_login))
  end

  it "redirects to login when not authenticated" do
    get portal_resources_path
    expect(response).to redirect_to(portal_login_path)
  end

  it "lists resources delivered to the participant, most recent first, deduped" do
    r1 = create(:resource, title: "Hábito ancla", kind: :video)
    r2 = create(:resource, title: "Fricción y entorno", kind: :article)
    create(:resource_delivery, participant: participant, resource: r1, created_at: 2.days.ago)
    create(:resource_delivery, participant: participant, resource: r1, created_at: 1.hour.ago)
    create(:resource_delivery, participant: participant, resource: r2, created_at: 1.day.ago)

    login!(participant)
    get portal_resources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hábito ancla")
    expect(response.body).to include("Fricción y entorno")
    expect(response.body.scan("Hábito ancla").size).to eq(1)
    expect(response.body.index("Hábito ancla")).to be < response.body.index("Fricción y entorno")
  end

  it "hides discarded resources" do
    r = create(:resource, title: "Recurso muerto")
    create(:resource_delivery, participant: participant, resource: r)
    r.discard

    login!(participant)
    get portal_resources_path

    expect(response.body).not_to include("Recurso muerto")
  end

  it "shows an empty state when no resources" do
    login!(participant)
    get portal_resources_path
    expect(response.body).to include("Aún no te hemos compartido recursos")
  end

  it "does not leak another participant's resources" do
    other = create(:participant, email: "o@e.com")
    r = create(:resource, title: "Solo de otro")
    create(:resource_delivery, participant: other, resource: r)

    login!(participant)
    get portal_resources_path

    expect(response.body).not_to include("Solo de otro")
  end
end
