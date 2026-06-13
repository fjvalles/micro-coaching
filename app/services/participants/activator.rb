module Participants
  # Flips a participant to active on day 1 and fires the welcome. Idempotent: a
  # participant who is already active is left untouched and no duplicate welcome is
  # sent. Single activation path shared by Enroller (free/immediate enroll), the
  # admin enroll action, and the Webpay commit (payment-gated enroll), so the
  # "becomes active → SendWelcomeJob" rule lives in exactly one place.
  #
  # PaperTrail attribution is inherited from the caller's context (admin controller,
  # public request, or job), so callers don't need to wrap this.
  class Activator
    def initialize(participant)
      @participant = participant
    end

    def call
      return @participant if @participant.active?

      @participant.update!(
        status: :active,
        current_day: 1,
        enrolled_at: @participant.enrolled_at || Time.current,
        started_at: @participant.started_at || Time.current
      )
      @participant.start_enrollment! # opens the cycle-1 ledger row for this program
      SendWelcomeJob.perform_later(@participant.id)
      @participant
    end
  end
end
