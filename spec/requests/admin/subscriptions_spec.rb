require "rails_helper"

RSpec.describe "Admin::Subscriptions", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/subscriptions" do
    it "renders the dashboard with active count and MRR" do
      create(:subscription, status: :active, amount_clp: 15_000)
      create(:subscription, status: :canceled, amount_clp: 9_000)

      get admin_subscriptions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("MRR")
      expect(response.body).to include("Suscripciones activas")
    end

    it "requires admin authentication" do
      Warden.test_reset!
      get admin_subscriptions_path
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end
end
