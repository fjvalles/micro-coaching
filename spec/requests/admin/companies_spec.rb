require "rails_helper"

RSpec.describe "Admin::Companies", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/companies" do
    it "lists kept companies" do
      company = create(:company, name: "Acme Latam")
      get "/admin/companies"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acme Latam")
    end
  end

  describe "POST /admin/companies" do
    it "creates a company and derives the slug" do
      expect {
        post "/admin/companies", params: { company: { name: "Nueva Empresa SpA", coach_name: "Sofía", covers_membership: "1" } }
      }.to change(Company, :count).by(1)

      company = Company.order(:created_at).last
      expect(company.slug).to eq("nueva-empresa-spa")
      expect(company.coach_name).to eq("Sofía")
      expect(response).to redirect_to(admin_company_path(company))
    end

    it "re-renders on invalid input" do
      post "/admin/companies", params: { company: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /admin/companies/:id" do
    it "shows the company and its participants" do
      company = create(:company, name: "Holding X")
      create(:participant, company: company, name: "Miembro Uno")
      get "/admin/companies/#{company.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Holding X")
      expect(response.body).to include("Miembro Uno")
    end
  end

  describe "archive / restore" do
    it "discards and restores a company" do
      company = create(:company)
      post "/admin/companies/#{company.id}/discard"
      expect(company.reload.discarded?).to be true

      post "/admin/companies/#{company.id}/undiscard"
      expect(company.reload.discarded?).to be false
    end
  end
end
