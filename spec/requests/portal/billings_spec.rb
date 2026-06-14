require "rails_helper"

RSpec.describe "Portal::Billings", type: :request do
  let(:participant) { create(:participant, email: "u@e.com") }

  def login!(p)
    get portal_session_path(p.generate_token_for(:portal_login))
  end

  it "redirects to login when not authenticated" do
    get portal_billing_path
    expect(response).to redirect_to(portal_login_path)
  end

  it "shows the participant's subscription and payments" do
    create(:subscription, participant: participant, plan: "monthly", amount_clp: 15_000, status: :active)
    create(:payment, participant: participant, amount: 15_000, status: :authorized, paid_at: Time.current)

    login!(participant)
    get portal_billing_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Activa")
    expect(response.body).to include("Pagado")
    expect(response.body).to include("15.000")
  end

  it "shows empty states with no billing data" do
    login!(participant)
    get portal_billing_path
    expect(response.body).to include("No tienes una suscripción activa")
    expect(response.body).to include("Todavía no registras pagos")
  end

  it "hides discarded subscriptions" do
    sub = create(:subscription, participant: participant, plan: "anual")
    sub.discard
    login!(participant)
    get portal_billing_path
    expect(response.body).not_to include("anual")
  end

  it "does not leak another participant's payments" do
    other = create(:participant, email: "o@e.com")
    create(:payment, participant: other, amount: 99_999, status: :authorized, buy_order: "IMP-OTHER-1")
    login!(participant)
    get portal_billing_path
    expect(response.body).not_to include("99.999")
  end

  it "shows the pay CTA when the participant must pay individually" do
    create(:program) # default
    allow(Setting).to receive(:fetch).and_call_original
    allow(Setting).to receive(:fetch).with("membership_price_clp").and_return("19990")
    allow(Setting).to receive(:fetch).with("webpay_enabled").and_return(true)

    login!(participant)
    get portal_billing_path
    expect(response.body).to include("Activa tu membresía")
    expect(response.body).to include("19.990")
  end
end
