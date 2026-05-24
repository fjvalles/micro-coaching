require "rails_helper"

RSpec.describe Admin::OnboardingHelper, type: :helper do
  # Include ApplicationHelper to make render_markdown available if needed
  helper do
    include ApplicationHelper
  end

  describe "#parse_guide_section" do
    context "with a valid pattern that exists in the guide" do
      it "extracts the title and body, cleaning up the title header" do
        result = helper.parse_guide_section(/Inscribir a un Nuevo Participante/)
        expect(result).not_to be_nil
        expect(result[:title]).to eq("Inscribir a un Nuevo Participante (Enrollment)")
        expect(result[:body]).to include("Para dar de alta a un usuario en el programa:")
        expect(result[:body]).to include("Teléfono:")
      end

      it "extracts new sections like daily reports successfully" do
        result = helper.parse_guide_section(/Reportes Diarios/)
        expect(result).not_to be_nil
        expect(result[:title]).to eq("Reportes Diarios y Patrones de IA")
        expect(result[:body]).to include("El sistema genera resúmenes diarios")
      end
    end

    context "with a pattern that doesn't exist" do
      it "returns nil" do
        result = helper.parse_guide_section(/This Pattern Definitely Does Not Exist Anywhere in the Guide/)
        expect(result).to be_nil
      end
    end
  end

  describe "#onboarding_keys_for" do
    it "maps dashboard controller to intro and sections keys" do
      expect(helper.onboarding_keys_for("dashboard", "index")).to eq([ :dashboard_intro, :dashboard_sections ])
    end

    it "maps participants controller show action to chat and pause keys" do
      expect(helper.onboarding_keys_for("participants", "show")).to eq([ :participant_chat, :participant_pause ])
    end

    it "maps participants controller index action to enrollment and archive keys" do
      expect(helper.onboarding_keys_for("participants", "index")).to eq([ :participant_enrollment, :participant_archive ])
    end

    it "maps day_contents controller to program_contents key" do
      expect(helper.onboarding_keys_for("day_contents", "index")).to eq([ :program_contents ])
    end

    it "maps conversations controller to conversations_history key" do
      expect(helper.onboarding_keys_for("conversations", "index")).to eq([ :conversations_history ])
    end

    it "maps daily_reports controller to daily_reports_analysis key" do
      expect(helper.onboarding_keys_for("daily_reports", "index")).to eq([ :daily_reports_analysis ])
    end

    it "maps settings controller to settings_live key" do
      expect(helper.onboarding_keys_for("settings", "index")).to eq([ :settings_live ])
    end

    it "returns empty array for unknown controllers" do
      expect(helper.onboarding_keys_for("unknown", "index")).to eq([])
    end
  end

  describe "#render_layout_onboarding" do
    before do
      # Stub controller_name and action_name inside the helper context
      allow(helper).to receive(:controller_name).and_return("dashboard")
      allow(helper).to receive(:action_name).and_return("index")
    end

    it "renders all mapped onboarding card partials for the current page" do
      html = helper.render_layout_onboarding
      expect(html).not_to be_nil
      expect(html).to include("onboarding-card")
      expect(html).to include("Introducción al Panel")
      expect(html).to include("Secciones del Sistema")
    end
  end
end
