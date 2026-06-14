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
      return Result.new(ok: false, reason: :already_active) if @participant.active? || @participant.completed?

      # awaiting_open: the first contact is a template (free text can't open a cold
      # 24h window); the participant's first reply opens the window and triggers Q1.
      PaperTrail.request(whodunnit: "ai:IntakeStarter", controller_info: { source: "ai" }) do
        @participant.update!(status: :intake, intake_state: { "step" => 0, "answers" => {}, "awaiting_open" => true })
      end
      SendIntakeOpenerJob.perform_later(@participant.id)

      Result.new(ok: true, reason: :started)
    end
  end
end
