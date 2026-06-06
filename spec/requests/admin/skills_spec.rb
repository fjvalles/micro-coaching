require "rails_helper"

RSpec.describe "Admin::Skills", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/skills" do
    let!(:skill) { create(:skill, name: "Habilidad de prueba visible") }

    it "renders the catalog with an integer count, not the grouped-relation hash" do
      create_list(:skill_detection, 2, skill: skill)

      get "/admin/skills"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(skill.name)
      expect(response.body).to include(skill.slug)
      # Regression: a grouped relation's #size returns a Hash {id => count};
      # the count badge must render the integer total instead of dumping the hash.
      expect(response.body).not_to match(/=&gt;\s*\d+/)
      expect(response.body).not_to match(/=>\s*\d+/)
    end

    it "filters skills by search query" do
      skill_match = create(:skill, name: "Empatia Activa", slug: "empatia-activa")
      skill_other = create(:skill, name: "Comunicacion Asertiva", slug: "comunicacion-asertiva")

      get "/admin/skills", params: { q: "empatia" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(skill_match.name)
      expect(response.body).not_to include(skill_other.name)
    end
  end

  describe "GET /admin/skills/:id" do
    let(:skill) { create(:skill, name: "Habilidad detalle") }

    it "renders a skill with its sections" do
      get admin_skill_path(skill)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(skill.name)
    end
  end
end
