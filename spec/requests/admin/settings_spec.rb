require "rails_helper"

RSpec.describe "Admin::Settings", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user, superadmin: true) }
  let(:regular) { create(:admin_user, email: "regular@example.com") }
  let!(:setting) { Setting.create!(key: "test_key", value: "test_value", category: "general", value_type: "string", description: "Test Description") }

  describe "without login" do
    it "redirects to sign in" do
      get "/admin/settings"
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a non-superadmin" do
    before { login_as(regular, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "forbids viewing the settings index" do
      get "/admin/settings"
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids editing a setting" do
      get "/admin/settings/#{setting.id}/edit"
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids updating a setting" do
      patch "/admin/settings/#{setting.id}", params: { setting: { value: "hacked" } }
      expect(response).to have_http_status(:forbidden)
      expect(setting.reload.value).to eq("test_value")
    end
  end

  describe "with login" do
    before { login_as(admin, scope: :admin_user) }
    after  { Warden.test_reset! }

    it "renders the settings index successfully" do
      get "/admin/settings"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Configuración del Sistema")
      expect(response.body).to include("test_key")
      expect(response.body).to include("Test Description")
      expect(response.body).to include("test_value")
    end

    it "renders the edit page" do
      get "/admin/settings/#{setting.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Editar Configuración: test_key")
    end

    it "updates the setting value successfully" do
      patch "/admin/settings/#{setting.id}", params: { setting: { value: "new_test_value" } }
      expect(response).to redirect_to(admin_settings_path)
      expect(flash[:notice]).to include("actualizada correctamente")
      expect(setting.reload.value).to eq("new_test_value")
    end

    it "renders edit with errors if validation fails" do
      # Let's mock a validation error
      allow_any_instance_of(Setting).to receive(:update).and_return(false)
      patch "/admin/settings/#{setting.id}", params: { setting: { value: "new_test_value" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
