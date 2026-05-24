module Admin
  class DailyReportsController < BaseController
    before_action :set_daily_report, only: [ :show, :destroy ]

    def index
      scope = DailyReport.all

      if params[:q].present?
        scope = scope.where("ai_summary ILIKE :q OR ai_key_pattern ILIKE :q", q: "%#{params[:q]}%")
      end

      if params[:participant_id].present?
        scope = scope.where(participant_id: params[:participant_id])
      end

      # Filter by program (through participant)
      if params[:program_id].present?
        if params[:program_id] == "none"
          scope = scope.joins(:participant).where(participants: { program_id: nil })
        else
          scope = scope.joins(:participant).where(participants: { program_id: params[:program_id] })
        end
      end

      # Filter by day_number
      if params[:day_number].present?
        scope = scope.where(day_number: params[:day_number])
      end

      # Filter by ai_key_pattern
      if params[:key_pattern].present?
        scope = scope.where(ai_key_pattern: params[:key_pattern])
      end

      # Filter by reported_at date range
      if params[:reported_from].present?
        begin
          scope = scope.where("reported_at >= ?", Time.zone.parse(params[:reported_from]).beginning_of_day)
        rescue ArgumentError, TypeError
        end
      end
      if params[:reported_to].present?
        begin
          scope = scope.where("reported_at <= ?", Time.zone.parse(params[:reported_to]).end_of_day)
        rescue ArgumentError, TypeError
        end
      end

      @page = (params[:page] || 1).to_i
      @per_page = 25
      @total_count = scope.count
      @total_pages = (@total_count.to_f / @per_page).ceil

      @programs = Program.ordered
      @key_patterns = DailyReport.where.not(ai_key_pattern: [ nil, "" ]).distinct.pluck(:ai_key_pattern).sort
      @daily_reports = scope.includes(:participant)
                            .order(reported_at: :desc)
                            .limit(@per_page)
                            .offset((@page - 1) * @per_page)
    end

    def show
    end

    def destroy
      @daily_report.destroy
      redirect_to admin_daily_reports_path, notice: "Reporte diario eliminado."
    end

    private

    def set_daily_report
      @daily_report = DailyReport.find(params[:id])
    end
  end
end
