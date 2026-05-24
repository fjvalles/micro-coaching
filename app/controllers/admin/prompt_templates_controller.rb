module Admin
  class PromptTemplatesController < BaseController
    before_action :set_template, only: [ :show, :edit, :update, :analyze, :apply_suggestion ]

    def index
      @templates = PromptTemplate.kept.ordered.includes(:program)
    end

    def show
      @versions = @template.prompt_versions.chronological.reverse
      @executions = @template.prompt_executions
        .recent
        .includes(:participant, :prompt_version)
        .then { |s| params[:day].present? ? s.for_day(params[:day]) : s }
        .then { |s| params[:moment].present? ? s.for_moment(params[:moment]) : s }
        .limit(100)
      @executions_by_day = @template.prompt_executions.group(:day_number).count
      @analyses = @template.prompt_analyses.recent.limit(10)
      @tab = params[:tab].presence || "executions"
    end

    def edit
    end

    def update
      body = params.require(:prompt_template).permit(:current_body, :change_note)
      version = @template.record_version!(
        body: body[:current_body],
        author: current_admin_user,
        change_note: body[:change_note].presence,
        origin: "admin"
      )
      redirect_to admin_prompt_template_path(@template), notice: "Versión v#{version.version} guardada."
    end

    def analyze
      AnalyzePromptJob.perform_later(@template.id)
      redirect_to admin_prompt_template_path(@template, tab: "analyses"), notice: "Análisis encolado. Recarga en unos segundos."
    end

    def apply_suggestion
      analysis = @template.prompt_analyses.find(params[:analysis_id])
      if analysis.suggested_body.blank?
        redirect_to admin_prompt_template_path(@template), alert: "El análisis no tiene una sugerencia aplicable."
        return
      end
      version = @template.record_version!(
        body: analysis.suggested_body,
        author: current_admin_user,
        change_note: "Aplicado desde análisis #{analysis.id}",
        origin: "analysis"
      )
      redirect_to admin_prompt_template_path(@template), notice: "Sugerencia aplicada como v#{version.version}."
    end

    private

    def set_template
      @template = PromptTemplate.find(params[:id])
    end
  end
end
