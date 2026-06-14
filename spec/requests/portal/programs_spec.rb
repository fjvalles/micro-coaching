require "rails_helper"

RSpec.describe "Portal::Programs", type: :request do
  let(:program) { create(:program, name: "Hábitos 14d", manifesto: "Tu manifiesto base.", total_days: 6) }
  let(:participant) { create(:participant, program: program, email: "u@e.com", current_day: 3) }

  def login!(p)
    get portal_session_path(p.generate_token_for(:portal_login))
  end

  before do
    create(:day_content, program: program, day_number: 1, phase: :see)
    create(:day_content, program: program, day_number: 2, phase: :see)
    create(:day_content, program: program, day_number: 3, phase: :choose)
    create(:day_content, program: program, day_number: 4, phase: :choose)
    create(:day_content, program: program, day_number: 5, phase: :anchor)
    create(:day_content, program: program, day_number: 6, phase: :anchor)
  end

  it "redirects to login when not authenticated" do
    get portal_program_path
    expect(response).to redirect_to(portal_login_path)
  end

  it "shows program name, manifesto, phase arc and current stage" do
    login!(participant)
    get portal_program_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Hábitos 14d")
    expect(response.body).to include("Tu manifiesto base.")
    expect(response.body).to include("Ver", "Elegir", "Anclar")
    expect(response.body).to include("phase-step current")
  end

  it "shows the closing manifesto (final report) when present" do
    participant.update!(closing_manifesto: "Cerraste tu ciclo con fuerza.")
    login!(participant)
    get portal_program_path
    expect(response.body).to include("Tu reporte final")
    expect(response.body).to include("Cerraste tu ciclo con fuerza.")
  end

  it "lists daily reports" do
    create(:daily_report, participant: participant, day_number: 2, ai_summary: "Resumen día 2")
    login!(participant)
    get portal_program_path
    expect(response.body).to include("Resumen día 2")
  end

  it "shows an empty state when participant has no program" do
    no_prog = create(:participant, program: nil, email: "np@e.com")
    login!(no_prog)
    get portal_program_path
    expect(response.body).to include("Todavía no tienes un programa asignado")
  end
end
