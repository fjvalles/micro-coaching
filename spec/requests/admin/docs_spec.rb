require "rails_helper"

RSpec.describe "Admin::Docs", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  describe "without login" do
    it "redirects index to sign in" do
      get "/admin/docs"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "with login" do
    before { login_as(admin, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "lists docs" do
      get "/admin/docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Reglas de Negocio")
      expect(response.body).to include("Decisiones")
      expect(response.body).to include("Metodología y Pedagogía")
      expect(response.body).to include("Arquitectura y Flujos")
      expect(response.body).to include("Manual del Administrador")
      expect(response.body).to include("Estrategia Comercial")
      expect(response.body).to include("Lean Canvas")
      expect(response.body).to include("Análisis DVF")
    end

    it "renders commercial strategy markdown as HTML" do
      get "/admin/docs/commercial-strategy"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estrategia Comercial")
      expect(response.body).to include("Impulso by Comtraining")
    end

    it "renders business-rules markdown as HTML" do
      get "/admin/docs/business-rules"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1")
      expect(response.body).to include("Reglas de Negocio")
    end

    it "renders pedagogy-coaching markdown as HTML" do
      get "/admin/docs/pedagogy"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Metodología de Micro-Coaching")
      expect(response.body).to include("Fase 1: VER")
    end

    it "renders architecture-flows markdown as HTML" do
      get "/admin/docs/architecture"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Arquitectura Técnica y Flujos")
      expect(response.body).to include("Prompt Caching en OpenAI")
    end

    it "renders admin-guide markdown as HTML" do
      get "/admin/docs/admin-guide"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Guía de Uso del Panel de Administración")
      expect(response.body).to include("Inscribir a un Nuevo Participante")
    end

    it "renders interaction-examples-reports markdown as HTML" do
      get "/admin/docs/interaction-examples-reports"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ejemplos de Interacciones")
    end

    it "404s unknown slug" do
      get "/admin/docs/nope"
      expect(response).to have_http_status(:not_found)
    end

    it "rejects path traversal via constraints" do
      get "/admin/docs/..%2F..%2Fetc%2Fpasswd"
      expect(response).to have_http_status(:not_found)
    end
  end
end
