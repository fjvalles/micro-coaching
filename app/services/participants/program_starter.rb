module Participants
  # Admin-triggered start for day 1. Activates the participant when needed,
  # ensures the enrollment ledger exists, then enqueues the same initial outbound
  # jobs the scheduled flow would eventually send.
  class ProgramStarter
    Result = Struct.new(:ok, :reason, keyword_init: true) do
      def ok? = ok
    end

    def initialize(participant)
      @participant = participant
    end

    def call
      return Result.new(ok: false, reason: :no_program) if @participant.program.blank?
      return Result.new(ok: false, reason: :completed) if @participant.completed?
      return Result.new(ok: false, reason: :already_past_day_one) if @participant.current_day.to_i > 1

      was_active = @participant.active?
      start_participant!
      enqueue_welcome_if_needed if was_active
      MorningWakeForParticipantJob.perform_later(@participant.id)

      Result.new(ok: true, reason: :started)
    end

    private

    def start_participant!
      if @participant.active?
        ensure_active_start_state!
      else
        Participants::Activator.new(@participant).call
        @participant.reload
      end
    end

    def ensure_active_start_state!
      @participant.update!(
        current_day: 1,
        enrolled_at: @participant.enrolled_at || Time.current,
        started_at: @participant.started_at || Time.current
      )
      @participant.start_enrollment!
    end

    def enqueue_welcome_if_needed
      return if welcome_already_handled?

      SendWelcomeJob.perform_later(@participant.id)
    end

    def welcome_already_handled?
      @participant.conversations.kept
                  .where(moment: :welcome, day_number: 0)
                  .where.not(sent_at: nil)
                  .exists? ||
        PendingResponse.kept
                       .where(participant: @participant, moment: "welcome", day_number: 0)
                       .where(status: %w[pending approved sent])
                       .exists?
    end
  end
end
