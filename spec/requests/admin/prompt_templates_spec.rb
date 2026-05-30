require "rails_helper"

RSpec.describe "Admin::PromptTemplates", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }
  let(:program) { create(:program, name: "Liderazgo", slug: "liderazgo") }

  let!(:template_global) do
    create(
      :prompt_template,
      name: "Prompt Global",
      key: "global_classifier",
      description: "Classifies general messages",
      program: nil,
      day_number: nil,
      source: "service"
    )
  end

  let!(:template_program_day) do
    create(
      :prompt_template,
      name: "Prompt Dia 1",
      key: "morning_wake_1",
      description: "Send wake up message for day 1",
      program: program,
      day_number: 1,
      source: "day_content"
    )
  end

  let!(:template_other) do
    create(
      :prompt_template,
      name: "Prompt Admin",
      key: "admin_override",
      description: "Manual admin template override",
      program: program,
      day_number: 2,
      source: "admin"
    )
  end

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/prompt_templates" do
    it "lists all prompt templates" do
      get "/admin/prompt_templates"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Prompt Global")
      expect(response.body).to include("Prompt Dia 1")
      expect(response.body).to include("Prompt Admin")
    end

    it "filters by program" do
      get "/admin/prompt_templates", params: { program_id: program.id }

      expect(response.body).to include("Prompt Dia 1")
      expect(response.body).to include("Prompt Admin")
      expect(response.body).not_to include("Prompt Global")
    end

    it "filters by global (none program)" do
      get "/admin/prompt_templates", params: { program_id: "none" }

      expect(response.body).to include("Prompt Global")
      expect(response.body).not_to include("Prompt Dia 1")
      expect(response.body).not_to include("Prompt Admin")
    end

    it "filters by day number" do
      get "/admin/prompt_templates", params: { day_number: 1 }

      expect(response.body).to include("Prompt Dia 1")
      expect(response.body).not_to include("Prompt Global")
      expect(response.body).not_to include("Prompt Admin")
    end

    it "filters by no day (none/global day)" do
      get "/admin/prompt_templates", params: { day_number: "none" }

      expect(response.body).to include("Prompt Global")
      expect(response.body).not_to include("Prompt Dia 1")
      expect(response.body).not_to include("Prompt Admin")
    end

    it "searches by name, key, or description" do
      get "/admin/prompt_templates", params: { q: "wake_wake" }
      # None should match this string exactly
      expect(response.body).not_to include("Prompt Global")

      get "/admin/prompt_templates", params: { q: "wake_1" }
      expect(response.body).to include("Prompt Dia 1")
      expect(response.body).not_to include("Prompt Global")
    end
  end
end
