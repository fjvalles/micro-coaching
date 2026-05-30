require "rails_helper"

RSpec.describe "Admin::Payments", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/payments" do
    it "renders the income dashboard with totals" do
      create(:payment, amount: 15_000, status: :authorized, paid_at: Time.current)
      get admin_payments_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ingreso bruto")
      expect(response.body).to include("Neto recibido")
    end
  end

  describe "GET /admin/payments/:id" do
    it "shows a payment detail" do
      payment = create(:payment, amount: 15_000, status: :authorized)
      get admin_payment_path(payment)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(payment.buy_order)
    end
  end
end
