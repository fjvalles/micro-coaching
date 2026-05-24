require "rails_helper"

RSpec.describe "Admin::Methodology", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }
  let!(:program) { create(:program, active: true) }

  describe "without login" do
    it "redirects to sign in" do
      get "/admin/metodologia"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with login" do
    before { login_as(admin, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "GET default tab (marco) renders 200" do
      get admin_methodology_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Metodología")
    end

    Admin::MethodologyController::TABS.each do |tab|
      it "GET tab=#{tab} renders 200" do
        get admin_methodology_path(tab: tab)
        expect(response).to have_http_status(:ok)
      end
    end

    it "POST refresh enqueues RefreshMethodologyInsightsJob and redirects" do
      expect {
        post admin_refresh_methodology_path
      }.to have_enqueued_job(RefreshMethodologyInsightsJob)
      expect(response).to redirect_to(admin_methodology_path(tab: "marco"))
    end
  end
end
