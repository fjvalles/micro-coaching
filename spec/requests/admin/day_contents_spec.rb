require "rails_helper"

RSpec.describe "Admin::DayContents", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }
  let(:program) { create(:program, name: "Liderazgo") }
  let(:other_program) { create(:program, name: "Cambio") }
  let!(:matching_content) do
    create(
      :day_content,
      program: program,
      day_number: 3,
      phase: :choose,
      title: "Feedback valiente",
      morning_template: "Practica una conversacion dificil",
      active: true
    )
  end
  let!(:inactive_content) do
    create(
      :day_content,
      program: program,
      day_number: 4,
      phase: :anchor,
      title: "Seguimiento",
      iareto_text: "Haz seguimiento al acuerdo",
      active: false
    )
  end
  let!(:other_program_content) do
    create(
      :day_content,
      program: other_program,
      day_number: 3,
      phase: :choose,
      title: "Gestion del cambio",
      checkin_questions: "Que aprendiste hoy?",
      active: true
    )
  end

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  def listed_titles
    Nokogiri::HTML(response.body).css("table tbody tr td:nth-child(3) a").map(&:text).map(&:strip)
  end

  describe "GET /admin/day_contents" do
    it "lists day contents" do
      get "/admin/day_contents", params: { per_page: 100 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(matching_content.title)
      expect(response.body).to include(other_program_content.title)
      expect(response.body).to include("Nuevo Día")
    end

    it "filters by program" do
      get "/admin/day_contents", params: { program_id: program.id }

      expect(listed_titles).to include(matching_content.title, inactive_content.title)
      expect(listed_titles).not_to include(other_program_content.title)
    end

    it "filters by day number" do
      get "/admin/day_contents", params: { day_number: 4 }

      expect(listed_titles).to include(inactive_content.title)
      expect(listed_titles).not_to include(matching_content.title)
    end

    it "filters by phase" do
      get "/admin/day_contents", params: { phase: "choose" }

      expect(listed_titles).to include(matching_content.title, other_program_content.title)
      expect(listed_titles).not_to include(inactive_content.title)
    end

    it "filters by status" do
      get "/admin/day_contents", params: { status: "inactive" }

      expect(listed_titles).to eq([ inactive_content.title ])
    end

    it "supports multi-select filters" do
      get "/admin/day_contents", params: {
        program_ids: [ program.id, other_program.id ],
        day_numbers: [ 3 ],
        phases: [ "choose" ],
        statuses: [ "active" ]
      }

      expect(listed_titles).to contain_exactly(matching_content.title, other_program_content.title)
    end

    it "searches by title and content text" do
      get "/admin/day_contents", params: { q: "conversacion dificil" }

      expect(listed_titles).to eq([ matching_content.title ])
    end
  end

  describe "GET /admin/programs/:program_id/day_contents" do
    it "shows only content from the selected program" do
      get "/admin/programs/#{program.id}/day_contents"

      expect(response).to have_http_status(:ok)
      expect(listed_titles).to include(matching_content.title, inactive_content.title)
      expect(listed_titles).not_to include(other_program_content.title)
    end
  end

  describe "POST /admin/programs/:program_id/day_contents" do
    it "creates a new day content for the selected program" do
      expect {
        post "/admin/programs/#{program.id}/day_contents", params: {
          day_content: {
            program_id: program.id,
            day_number: 8,
            phase: "see",
            title: "Nuevo contenido",
            morning_template: "Buenos dias",
            iareto_text: "Nuevo reto",
            checkin_questions: "Como te fue?",
            ai_system_prompt: "Acompana con firmeza",
            active: true
          },
          return_to_program_id: program.id
        }
      }.to change(DayContent, :count).by(1)

      new_day_content = DayContent.find_by!(title: "Nuevo contenido")
      expect(new_day_content.program).to eq(program)
      expect(response).to redirect_to(admin_day_content_path(new_day_content, return_to_program_id: program.id))
    end
  end
end
