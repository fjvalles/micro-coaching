module Admin
  class PromptTuningController < BaseController
    before_action :require_superadmin
    before_action :set_run, only: [ :show, :approve, :update_and_approve, :reject, :rollback ]

    def index
      @pending_runs = PromptTuningRun.pending.recent
      @runs = PromptTuningRun.recent.limit(50)
      @latest_score = ConversationQualityScore.recent.first
    end

    def show
      @diff_rows = bullet_diff(@run.current_guardrails, @run.proposed_guardrails.presence || @run.applied_guardrails)
    end

    def approve
      if @run.apply!(author: current_admin_user)
        redirect_to admin_prompt_tuning_path(@run), notice: "Guardrails aplicados."
      else
        redirect_to admin_prompt_tuning_path(@run), alert: @run.validation_errors.join(", ")
      end
    end

    def update_and_approve
      @run.update!(proposed_guardrails: params.require(:prompt_tuning_run).permit(:proposed_guardrails)[:proposed_guardrails])
      approve
    end

    def reject
      @run.reject!
      redirect_to admin_prompt_tuning_index_path, notice: "Propuesta rechazada."
    end

    def rollback
      if @run.rollback!(post_score: @run.post_score || @run.score)
        redirect_to admin_prompt_tuning_path(@run), notice: "Rollback aplicado."
      else
        redirect_to admin_prompt_tuning_path(@run), alert: "No hay guardrails previos para revertir."
      end
    end

    private

    def set_run
      @run = PromptTuningRun.find(params[:id])
    end

    def bullet_diff(before, after)
      before_lines = split_bullets(before)
      after_lines = split_bullets(after)
      all = (before_lines + after_lines).uniq
      all.map do |line|
        {
          body: line,
          before: before_lines.include?(line),
          after: after_lines.include?(line)
        }
      end
    end

    def split_bullets(text)
      text.to_s.lines.map(&:strip).reject(&:blank?)
    end
  end
end
