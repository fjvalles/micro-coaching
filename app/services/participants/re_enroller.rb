module Participants
  # Transitions a participant into a new program cycle — typically the completed
  # program's next_program ("Nivel 1" → "Nivel 2"), but any target program works.
  # Repoints the live state (program_id, current_day: 1, status: active) and opens
  # a fresh ledger cycle via start_enrollment!, then fires the welcome.
  #
  # The previous cycle should already be marked :completed by DayAdvancer; if the
  # participant is re-enrolled mid-program, the prior active cycle is canceled so
  # the ledger never holds two active rows.
  class ReEnroller
    Result = Struct.new(:participant, :enrollment, :ok, keyword_init: true)

    def initialize(participant, program: nil)
      @participant = participant
      @program = program || participant.program&.next_program
    end

    def call
      return Result.new(participant: @participant, ok: false) if @program.nil?

      ActiveRecord::Base.transaction do
        cancel_stale_active_cycle
        @participant.update!(program: @program, status: :active, current_day: 1, started_at: Time.current)
        @enrollment = @participant.start_enrollment!(@program)
      end

      reset_participant_memory
      SendWelcomeJob.perform_later(@participant.id)
      Result.new(participant: @participant, enrollment: @enrollment, ok: true)
    end

    private

    def cancel_stale_active_cycle
      @participant.enrollments.active.where.not(program_id: @program.id)
                  .update_all(status: Enrollment.statuses[:canceled], updated_at: Time.current)
    end

    # The rolling AI memory belongs to the prior program's journey; start the new
    # cycle clean so coaching doesn't drag stale context across programs.
    def reset_participant_memory
      @participant.update!(ai_summary: nil, ai_summary_updated_at: nil)
    end
  end
end
