module Participants
  # Puts a participant into the personalized-program intake flow: flips status to
  # :intake, resets intake state, and sends the opener template over WhatsApp (free
  # text can't open a cold 24h window). Idempotent — re-running for someone already
  # in intake just re-sends the opener (SendIntakeOpenerJob dedupes). Gated by the
  # program_intake_enabled kill-switch.
  #
  # Entry point shared by the admin "armar programa personalizado" action and any
  # future self-serve signup that opts into a custom program.
  class IntakeStarter
    Result = Struct.new(:ok, :reason, keyword_init: true) do
      def ok? = ok
    end

    def initialize(participant)
      @participant = participant
    end

    def call
      return Result.new(ok: false, reason: :disabled) unless Setting.fetch("program_intake_enabled")
      # A completed participant may re-enter intake to design their paid Nivel 2 (the
      # day-14 upsell). Only an actively-running program blocks a new intake.
      return Result.new(ok: false, reason: :already_active) if @participant.active?

      # awaiting_open: the first contact is a template (free text can't open a cold
      # 24h window); the participant's first reply opens the window and triggers Q1.
      # current_day: 0 — intake sits between programs. A returning completed
      # participant carries current_day = total_days + 1 from DayAdvancer#complete!,
      # which would fail the program-range validation under the :intake status.
      PaperTrail.request(whodunnit: "ai:IntakeStarter", controller_info: { source: "ai" }) do
        @participant.update!(status: :intake, current_day: 0,
                             intake_state: { "step" => 0, "answers" => {}, "awaiting_open" => true })
      end
      SendIntakeOpenerJob.perform_later(@participant.id)

      Result.new(ok: true, reason: :started)
    end
  end
end
