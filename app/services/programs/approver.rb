module Programs
  # Promotes a reviewed/accepted TEMPLATE into the participant's live program and
  # starts them on day 1. Shared by the automated generation path (when review is
  # not required) and the admin approval action. Idempotent: a participant who is
  # already active is returned untouched.
  #
  # Seeds initial_pattern from the intake "pattern" answer so the welcome flow does
  # not re-ask the question the participant already answered during intake.
  class Approver
    def initialize(participant:, template:)
      @participant = participant
      @template = template
    end

    def call
      return @participant if @participant.active?

      clone = Programs::Cloner.new(template: @template, company: @participant.company).call

      PaperTrail.request(whodunnit: "ai:Programs::Approver", controller_info: { source: "ai" }) do
        @participant.update!(
          program: clone,
          initial_pattern: pattern_seed,
          intake_state: @participant.intake_state.merge("awaiting_review" => false, "approved_at" => Time.current.iso8601)
        )
      end

      if returning?
        # Already ran a prior cycle (e.g. completed the free Nivel 1, now buying a
        # personalized Nivel 2): open a fresh ledger cycle and reset the rolling AI
        # memory rather than first-activating on day 1.
        Participants::ReEnroller.new(@participant, program: clone).call
      else
        Participants::Activator.new(@participant).call
      end
      clone
    end

    private

    # A participant with prior enrollment cycles is returning into a new program,
    # not enrolling for the first time.
    def returning?
      @participant.enrollments.exists?
    end

    def pattern_seed
      @participant.intake_answers["pattern"].presence&.truncate(500) || @participant.initial_pattern
    end
  end
end
