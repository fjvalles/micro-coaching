module Portal
  # Programa actual: manifiesto, arco de fases, etapa actual, reportes diarios y
  # el manifiesto de cierre (reporte final) cuando el programa se completa.
  class ProgramsController < BaseController
    def show
      @program = current_participant.program
      @total_days = @program&.total_days || 14
      @reports = current_participant.daily_reports.order(reported_at: :desc)
      @closing_manifesto = current_participant.closing_manifesto

      @phases = phase_arc
    end

    private

    # Ordered unique phases of the program with their state relative to where the
    # participant is now: :done | :current | :upcoming.
    def phase_arc
      return [] if @program.nil?

      # phase is an integer enum; map(&:phase) yields string keys ("see"/…).
      ordered = DayContent.where(program: @program).order(:day_number).map(&:phase).uniq
      current = current_participant.day_content&.phase
      current_idx = ordered.index(current)

      ordered.each_with_index.map do |phase, idx|
        state = if current_idx.nil?
                  :upcoming
        elsif idx < current_idx
                  :done
        elsif idx == current_idx
                  :current
        else
                  :upcoming
        end
        [ phase, state ]
      end
    end
  end
end
