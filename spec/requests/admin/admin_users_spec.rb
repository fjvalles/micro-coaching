require "rails_helper"

RSpec.describe "Admin::AdminUsers", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user, name: "Super Admin") }
  let!(:other_admin) { create(:admin_user, name: "Regular Admin", email: "regular@example.com") }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/admin_users" do
    it "lists admin users and their names" do
      get "/admin/admin_users"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Super Admin")
      expect(response.body).to include("Regular Admin")
      expect(response.body).to include("Nuevo Administrador")
    end
  end

  describe "POST /admin/admin_users" do
    it "creates a new admin user with a name" do
      expect {
        post "/admin/admin_users", params: {
          admin_user: {
            name: "New Admin",
            email: "new_admin@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.to change(AdminUser, :count).by(1)

      expect(response).to redirect_to(admin_admin_users_path)
      follow_redirect!
      expect(response.body).to include("Usuario administrador creado exitosamente.")

      new_user = AdminUser.find_by(email: "new_admin@example.com")
      expect(new_user.name).to eq("New Admin")
    end

    it "fails to create when name is missing" do
      expect {
        post "/admin/admin_users", params: {
          admin_user: {
            name: "",
            email: "invalid_admin@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      }.not_to change(AdminUser, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Nombre can&#39;t be blank")
    end
  end

  describe "PATCH /admin/admin_users/:id" do
    it "updates the admin user name and email" do
      patch "/admin/admin_users/#{other_admin.id}", params: {
        admin_user: {
          name: "Updated Name",
          email: "updated_email@example.com"
        }
      }

      expect(response).to redirect_to(admin_admin_users_path)
      other_admin.reload
      expect(other_admin.name).to eq("Updated Name")
      expect(other_admin.email).to eq("updated_email@example.com")
    end
  end

  describe "DELETE /admin/admin_users/:id" do
    it "deletes the admin user" do
      expect {
        delete "/admin/admin_users/#{other_admin.id}"
      }.to change(AdminUser, :count).by(-1)

      expect(response).to redirect_to(admin_admin_users_path)
    end

    it "does not allow deleting oneself" do
      expect {
        delete "/admin/admin_users/#{admin.id}"
      }.not_to change(AdminUser, :count)

      expect(response).to redirect_to(admin_admin_users_path)
      follow_redirect!
      expect(response.body).to include("No puedes eliminarte a ti mismo.")
    end
  end
end
