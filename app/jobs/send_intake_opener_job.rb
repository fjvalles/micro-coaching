class SendIntakeOpenerJob < ApplicationJob
  queue_as :default

  # First contact of the personalized-program intake. A brand-new participant has no
  # open 24h window, so WhatsApp rejects free-form text — the opener must be an
  # approved template. The template opens the conversation; the participant's first
  # reply opens the 24h window, and ProcessIncomingMessageJob#handle_program_intake
  # then sends the first question as free text. Idempotent.
  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return unless participant.intake?
    return if opener_already_sent?(participant)

    template = Setting.fetch("intake_opener_template").to_s.presence || "bienvenida_piloto"
    Outbound::Dispatcher.new(
      participant: participant, moment: :program_intake, day_number: 0
    ).send_template(
      template_name: template,
      variables: [ participant.name ],
      body_preview: "Apertura de intake personalizado para #{participant.name}"
    )
  end

  private

  def opener_already_sent?(participant)
    participant.conversations.kept
               .where(moment: :program_intake, role: :assistant)
               .where.not(sent_at: nil)
               .exists? ||
      PendingResponse.kept
                     .where(participant: participant, moment: "program_intake")
                     .where(status: %w[pending approved sent])
                     .exists?
  end
end
