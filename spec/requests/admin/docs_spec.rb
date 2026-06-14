require "rails_helper"

RSpec.describe "Admin::Docs", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user, superadmin: true) }
  let(:regular) { create(:admin_user, email: "regular@example.com") }

  describe "without login" do
    it "redirects index to sign in" do
      get "/admin/docs"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a non-superadmin" do
    before { login_as(regular, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "hides technical docs from the index but keeps strategy docs" do
      get "/admin/docs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estrategia Comercial")
      expect(response.body).to include("Manual del Administrador")
      expect(response.body).not_to include("Reglas de Negocio")
      expect(response.body).not_to include("Arquitectura y Flujos")
    end

    it "forbids the technical documentation tab" do
      get "/admin/docs/technical"
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids opening a technical doc" do
      get "/admin/docs/business-rules"
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids opening the technical guide (CLAUDE.md)" do
      get "/admin/docs/claude"
      expect(response).to have_http_status(:forbidden)
    end

    it "still allows the strategy tab and a strategy doc" do
      get "/admin/docs/strategy"
      expect(response).to have_http_status(:ok)

      get "/admin/docs/commercial-strategy"
      expect(response).to have_http_status(:ok)
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

    it "renders the technical documentation view" do
      get "/admin/docs/technical"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Documentación Técnica")
      expect(response.body).not_to include("Documentos de Referencia (Markdown)")
    end

    it "renders the strategy documentation view" do
      get "/admin/docs/strategy"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Estrategia")
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
