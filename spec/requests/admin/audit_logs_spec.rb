require "rails_helper"

RSpec.describe "Admin::AuditLogs", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }
  let!(:program) { create(:program) }

  describe "without login" do
    it "redirects to sign in" do
      get "/admin/audit_log"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with login" do
    before { login_as(admin, scope: :admin_user) }
    after  { Warden.test_reset! }

    context "when rendering index" do
      before do
        PaperTrail.request.whodunnit = "test_admin@example.com"
        # Generate some audit log history
        program.update!(name: "Updated Program Name")
      end

      it "renders the audit logs page successfully" do
        get "/admin/audit_log"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Auditoría")
        expect(response.body).to include("Historial de cambios")
        expect(response.body).to include("test_admin@example.com")
        expect(response.body).to include("Updated Program Name")
      end

      it "filters by item_type" do
        get "/admin/audit_log", params: { item_type: "Program" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Programa")
      end

      it "filters by event" do
        get "/admin/audit_log", params: { event: "update" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Modificar")
      end

      it "searches by query text" do
        get "/admin/audit_log", params: { q: "Updated Program Name" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Updated Program Name")
      end

      it "returns no results for mismatching query" do
        get "/admin/audit_log", params: { q: "NonExistentNameQuery" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sin historial")
      end
    end
  end
end
