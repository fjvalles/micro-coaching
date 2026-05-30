require "rails_helper"

RSpec.describe "Admin::PendingResponses", type: :request do
  include Warden::Test::Helpers
  include ActiveJob::TestHelper

  let(:admin) { create(:admin_user) }
  let(:program) { create(:program) }
  let(:participant) { create(:participant, program: program) }
  let!(:pending_response) { create(:pending_response, participant: participant, status: "pending", draft_body: "Borrador de prueba") }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/pending_responses/:id" do
    it "renders the detail page successfully with participant context" do
      get "/admin/pending_responses/#{pending_response.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).to include("Borrador de prueba")
      expect(response.body).to include("Revisar Mensaje Borrador")
    end
  end

  describe "PATCH /admin/pending_responses/:id" do
    it "updates the draft body and redirects to index" do
      patch "/admin/pending_responses/#{pending_response.id}", params: {
        pending_response: { draft_body: "Borrador modificado" }
      }
      expect(response).to redirect_to(admin_pending_responses_path)
      follow_redirect!
      expect(response.body).to include("Borrador actualizado.")
      expect(pending_response.reload.draft_body).to eq("Borrador modificado")
    end
  end

  describe "POST /admin/pending_responses/:id/approve" do
    it "saves any edited body, marks response as approved, and redirects" do
      post "/admin/pending_responses/#{pending_response.id}/approve", params: {
        pending_response: { draft_body: "Borrador final aprobado" }
      }
      expect(response).to redirect_to(admin_pending_responses_path)
      follow_redirect!
      expect(response.body).to include("Aprobado.")

      pending_response.reload
      expect(pending_response.status).to eq("approved")
      expect(pending_response.draft_body).to eq("Borrador final aprobado")
      expect(pending_response.approved_by).to eq(admin)
      expect(pending_response.acted_at).not_to be_nil
    end
  end

  describe "POST /admin/pending_responses/:id/send_now" do
    it "saves any edited body, enqueues the Outbound::SendApprovedJob, and redirects" do
      expect {
        post "/admin/pending_responses/#{pending_response.id}/send_now", params: {
          pending_response: { draft_body: "Enviar este cuerpo ya" }
        }
      }.to have_enqueued_job(Outbound::SendApprovedJob).with(pending_response.id, admin.id)

      expect(response).to redirect_to(admin_pending_responses_path)
      follow_redirect!
      expect(response.body).to include("Encolado para envío.")

      pending_response.reload
      expect(pending_response.draft_body).to eq("Enviar este cuerpo ya")
    end
  end

  describe "POST /admin/pending_responses/:id/reject" do
    it "marks the response as rejected, stores the rejection reason, and redirects" do
      post "/admin/pending_responses/#{pending_response.id}/reject", params: {
        rejection_reason: "Texto muy largo"
      }
      expect(response).to redirect_to(admin_pending_responses_path)
      follow_redirect!
      expect(response.body).to include("Rechazado.")

      pending_response.reload
      expect(pending_response.status).to eq("rejected")
      expect(pending_response.rejection_reason).to eq("Texto muy largo")
      expect(pending_response.approved_by).to eq(admin)
      expect(pending_response.acted_at).not_to be_nil
    end
  end
end
