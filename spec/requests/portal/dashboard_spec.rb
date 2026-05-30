require "rails_helper"

RSpec.describe "Portal::Dashboard", type: :request do
  let(:participant) { create(:participant, email: "u@e.com", current_day: 5) }

  def login!(p)
    get portal_session_path(p.generate_token_for(:portal_login))
  end

  it "redirects to login when not authenticated" do
    get portal_root_path
    expect(response).to redirect_to(portal_login_path)
  end

  it "shows progress and reports when authenticated" do
    create(:daily_report, participant: participant, day_number: 4, ai_summary: "Resumen de prueba", reported_at: Time.current)
    login!(participant)
    get portal_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(participant.name)
    expect(response.body).to include("Resumen de prueba")
  end

  it "does not load a discarded participant's session" do
    login!(participant)
    participant.discard
    get portal_root_path
    expect(response).to redirect_to(portal_login_path)
  end
end
