module Admin
  class MethodologyController < BaseController
    TABS = %w[marco lecciones fases prompts evidencia].freeze
    DEFAULT_TAB = "marco".freeze

    def index
      @tab = TABS.include?(params[:tab]) ? params[:tab] : DEFAULT_TAB
      @program = Program.find_by(id: params[:program_id]) || Program.where(active: true).first

      @last_refresh = MethodologyInsight.recent.first&.generated_at
      @refresh_by_scope = MethodologyInsight::SCOPES.index_with do |scope|
        MethodologyInsight.latest_for(scope, program: @program)&.generated_at
      end

      case @tab
      when "lecciones"
        @cluster_insight = MethodologyInsight.latest_for("key_pattern_cluster", program: @program)
      when "fases"
        @phase_kpi   = MethodologyInsight.latest_for("phase_kpi",            program: @program)
        @voice_trend = MethodologyInsight.latest_for("voice_trend_by_phase", program: @program)
      when "prompts"
        @prompt_evolution = MethodologyInsight.latest_for("prompt_evolution", program: @program)
        @prompt_digest    = MethodologyInsight.latest_for("prompt_finding_digest", program: @program)
      when "evidencia"
        @stuck_insight    = MethodologyInsight.latest_for("stuck_pattern", program: @program)
        @prompt_digest    = MethodologyInsight.latest_for("prompt_finding_digest", program: @program)
      end
    end

    def refresh
      RefreshMethodologyInsightsJob.perform_later
      tab = TABS.include?(params[:tab]) ? params[:tab] : DEFAULT_TAB
      redirect_to admin_methodology_path(tab: tab),
                  notice: "Recálculo encolado. Recarga en unos minutos."
    end
  end
end
