require "rails_helper"

RSpec.describe "Admin::Sessions", type: :request do
  describe "GET /admin_users/sign_in" do
    it "renders the custom login page successfully" do
      get "/admin_users/sign_in"
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Impulso")
      expect(response.body).to include("Panel de Administración")
      expect(response.body).to include("Correo Electrónico")
      expect(response.body).to include("Contraseña")
      expect(response.body).to include("Iniciar Sesión")
      expect(response.body).to include("login-page-wrapper")
      expect(response.body).to include("login-card")
    end
  end

  describe "GET /admin_users/password/new" do
    it "renders the custom forgot password page successfully" do
      get "/admin_users/password/new"
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("¿Olvidaste tu contraseña?")
      expect(response.body).to include("Ingresa tu correo para recibir instrucciones de recuperación")
      expect(response.body).to include("Correo Electrónico")
      expect(response.body).to include("Enviar Instrucciones")
      expect(response.body).to include("login-page-wrapper")
      expect(response.body).to include("login-card")
    end
  end
end
