require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  describe "without login" do
    it "redirects to sign in" do
      get "/admin"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with login" do
    before { login_as(admin, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "renders the dashboard" do
      get "/admin"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Participantes Activos")
      expect(response.body).to include("Tasa de Respuesta")
      expect(response.body).to include("Consumo OpenAI")
    end

    context "with analytical data present" do
      let!(:program) { create(:program) }
      let!(:active_participant) { create(:participant, program: program, status: :active, current_day: 3) }

      # Stuck participant: active, created > 3 days ago, and has no user messages in the last 3 days
      let!(:stuck_participant) do
        create(:participant,
               program: program,
               status: :active,
               current_day: 5,
               created_at: 4.days.ago,
               enrolled_at: 4.days.ago)
      end

      # Failed message
      let!(:failed_conversation) do
        create(:conversation,
               participant: active_participant,
               role: :assistant,
               error_message: "Meta API error: invalid access token")
      end

      # Message with tokens
      let!(:billed_conversation) do
        create(:conversation,
               participant: active_participant,
               role: :assistant,
               tokens_input: 100000,
               tokens_output: 50000)
      end

      it "calculates and renders analytics, stuck list, and error table" do
        get "/admin"

        expect(response).to have_http_status(:ok)

        # Verify stuck participant is listed
        expect(response.body).to include(stuck_participant.name)
        expect(response.body).to include("Participantes Estancados")

        # Verify failed message is listed
        expect(response.body).to include("Meta API error: invalid access token")
        expect(response.body).to include("Errores de Envío Recientes")

        # Verify token counts and cost format are calculated ($0.045 USD)
        # Cost: 100k input * 0.15/1M + 50k output * 0.60/1M = 0.015 + 0.030 = 0.045
        expect(response.body).to include("$0.045 USD")
      end
    end
  end
end
