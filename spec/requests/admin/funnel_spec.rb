require "rails_helper"

RSpec.describe "Admin::Funnel & ProgramReviews", type: :request do
  let(:admin) { create(:admin_user) }

  before { login_as(admin, scope: :admin_user) }

  it "renders the conversion funnel" do
    create(:participant, status: :completed, completed_at: Time.current, nivel2_offer_sent_at: 1.hour.ago)
    get admin_funnel_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Embudo")
  end

  it "renders the program review queue with a participant awaiting review" do
    create(:participant, status: :intake, program: nil, current_day: 0,
           intake_state: { "awaiting_review" => true, "template_program_id" => SecureRandom.uuid })
    get admin_program_reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Programas personalizados por revisar (1)")
    expect(response.body).to include("Revisar y aprobar")
  end

  it "hides the program review section when the queue is empty" do
    get admin_program_reviews_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Programas personalizados por revisar")
    expect(response.body).not_to include("No hay programas pendientes")
  end
end
