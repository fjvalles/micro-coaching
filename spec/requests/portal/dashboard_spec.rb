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

  it "previews recent shared resources with a link to all" do
    r = create(:resource, title: "Recurso destacado")
    create(:resource_delivery, participant: participant, resource: r)
    login!(participant)
    get portal_root_path
    expect(response.body).to include("Recurso destacado")
    expect(response.body).to include("Ver todos")
  end

  it "shows the final-report banner when completed with a closing manifesto" do
    participant.update!(status: :completed, closing_manifesto: "Cierre.")
    login!(participant)
    get portal_root_path
    expect(response.body).to include("Tu reporte final está listo")
  end

  it "shows the Nivel 2 unlock CTA when a paid personalized program is offered" do
    Setting.set("webpay_enabled", true)
    template = create(:program, template: true, generated: true, active: false,
                      price_clp: 30_000, founder_price_clp: 19_000)
    participant.update!(status: :completed, nivel2_offer_sent_at: 1.hour.ago,
                        intake_state: { "template_program_id" => template.id, "offered_at" => Time.current.iso8601 })
    login!(participant)
    get portal_root_path

    expect(response.body).to include("Desbloquea tu Nivel 2")
    expect(response.body).to include("19.000") # founder price inside the window
  end
end
