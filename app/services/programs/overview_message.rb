module Programs
  # Builds the deterministic "what to expect" message sent when a participant starts
  # a program (fresh enroll or approved personalized program). Sets expectations and
  # reduces uncertainty to improve completion. Grounded entirely in the program's own
  # data — never reveals specific future-day challenges (see business-rules restricted
  # content rule), only the structure, cadence, and arc.
  #
  # Returns a ready-to-send String, or nil when there is no program to describe.
  class OverviewMessage
    PHASE_ARC = {
      "see"    => "Ver — primero observas tu patrón actual sin juzgarlo.",
      "choose" => "Elegir — empiezas a responder distinto, a propósito.",
      "anchor" => "Anclar — consolidas el nuevo hábito para que se sostenga."
    }.freeze

    def initialize(participant)
      @participant = participant
      @program = participant.program
    end

    def call
      return if @program.nil?

      <<~MSG.strip
        🎯 Tu programa: #{@program.name}

        Dura #{@program.total_days} #{'día'.pluralize(@program.total_days)}. Así funciona, para que sepas qué esperar:

        • Cada mañana te escribo con una idea corta y un micro-reto para el día.
        • Cada noche te hago un check-in breve (2-3 min) para cerrar el día.

        El recorrido tiene tres momentos:
        #{phase_arc}

        Lo único que necesitas hacer es responder por aquí. Son unos 5-10 minutos al día.

        No tienes que prepararte ni saber nada de antemano: vamos paso a paso, un día a la vez.#{coach_signoff}
      MSG
    end

    private

    # Lists only the phases the program actually uses, in see→choose→anchor order.
    def phase_arc
      present = @program.day_contents.active.distinct.pluck(:phase)
      ordered = PHASE_ARC.keys & normalize(present)
      ordered = PHASE_ARC.keys if ordered.empty?
      ordered.each_with_index.map { |phase, i| "#{i + 1}. #{PHASE_ARC[phase]}" }.join("\n")
    end

    # group/pluck on an enum column can return integer DB values; map back to names.
    def normalize(phases)
      phases.map { |p| p.is_a?(Integer) ? DayContent.phases.key(p) : p.to_s }
    end

    def coach_signoff
      coach = @participant.coach_name.presence || Setting.fetch("coach_name").to_s.strip
      coach.blank? ? "" : " Cuento contigo. — #{coach}"
    end
  end
end
