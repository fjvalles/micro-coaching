require "rails_helper"

RSpec.describe "Admin::ProfitLoss", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before do
    login_as(admin, scope: :admin_user)
    Setting.set("usd_clp_rate", 1000.0)
    Setting.set("tax_rate", 0.19)
  end

  after { Warden.test_reset! }

  describe "GET /admin/resultado" do
    it "renders the P&L with income, costs and margin" do
      create(:payment, amount: 11_900, status: :authorized, paid_at: Time.current,
                       commission_amount: 200, net_amount: 11_700)

      get admin_profit_loss_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Resultado")
      expect(response.body).to include("Margen")
      expect(response.body).to include("Ingreso bruto")
    end

    it "respects the period filter without error" do
      get admin_profit_loss_path(period: "last_month")
      expect(response).to have_http_status(:ok)
    end

    it "requires admin authentication" do
      Warden.test_reset!
      get admin_profit_loss_path
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end
end
