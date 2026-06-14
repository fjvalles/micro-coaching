require "rails_helper"

RSpec.describe "Portal::Profiles", type: :request do
  let(:participant) { create(:participant, email: "u@e.com", name: "Camila", timezone: "America/Santiago") }

  def login!(p)
    get portal_session_path(p.generate_token_for(:portal_login))
  end

  it "redirects to login when not authenticated" do
    get portal_profile_path
    expect(response).to redirect_to(portal_login_path)
  end

  it "shows the profile with editable name/timezone and read-only contact info" do
    login!(participant)
    get portal_profile_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Camila")
    expect(response.body).to include("u@e.com")
    expect(response.body).to include(participant.phone_e164)
  end

  it "updates name and timezone" do
    login!(participant)
    patch portal_profile_path, params: { participant: { name: "Camila Soto", timezone: "America/Lima" } }
    expect(response).to redirect_to(portal_profile_path)
    participant.reload
    expect(participant.name).to eq("Camila Soto")
    expect(participant.timezone).to eq("America/Lima")
  end

  it "rejects an invalid timezone" do
    login!(participant)
    patch portal_profile_path, params: { participant: { timezone: "Mars/Olympus" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(participant.reload.timezone).to eq("America/Santiago")
  end

  it "does not allow editing email or phone via mass assignment" do
    login!(participant)
    patch portal_profile_path, params: { participant: { name: "X", email: "hacked@e.com", phone_e164: "+560000000000" } }
    participant.reload
    expect(participant.email).to eq("u@e.com")
    expect(participant.phone_e164).not_to eq("+560000000000")
  end
end
