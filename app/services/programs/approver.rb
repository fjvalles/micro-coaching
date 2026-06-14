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

      Participants::Activator.new(@participant).call
      clone
    end

    private

    def pattern_seed
      @participant.intake_answers["pattern"].presence&.truncate(500) || @participant.initial_pattern
    end
  end
end
