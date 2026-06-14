class ProgramGenerationJob < ApplicationJob
  queue_as :default

  # Builds a personalized program from a participant's completed intake answers.
  # gen → build template → (review gate) → approve (clone + activate).
  #
  # Idempotency: bails if the participant already has a live program or is already
  # past intake. The kill-switch program_intake_enabled gates the whole feature.
  def perform(participant_id)
    participant = Participant.kept.find(participant_id)
    return unless Setting.fetch("program_intake_enabled")
    return unless participant.intake?
    return if participant.intake_awaiting_review?

    result = Openai::ProgramGenerator.new(answers: participant.intake_answers).call
    return generation_failed(participant) unless result.ok?

    build = Programs::Builder.new(spec: result.spec, company: participant.company).call
    return generation_failed(participant) unless build.ok?

    template = build.program

    if Setting.fetch("program_intake_review_required")
      flag_for_review(participant, template)
    else
      Programs::Approver.new(participant: participant, template: template).call
    end
  end

  private

  # Leaves the template inactive for an admin to review, then approve via
  # Programs::Approver (admin action / console). Participant stays in :intake until
  # approved, but stops re-generating on further inbound.
  def flag_for_review(participant, template)
    PaperTrail.request(whodunnit: "ai:ProgramGenerationJob", controller_info: { source: "ai" }) do
      participant.update!(
        intake_state: participant.intake_state.merge(
          "awaiting_review" => true,
          "template_program_id" => template.id
        )
      )
    end
    Rails.logger.info("ProgramGenerationJob: template #{template.id} awaiting review for participant #{participant.id}")
  end

  def generation_failed(participant)
    Rails.logger.warn("ProgramGenerationJob: generation failed for participant #{participant.id}")
    Sentry.capture_message("Program generation failed", level: :warning, extra: { participant_id: participant.id }) if defined?(Sentry)

    Outbound::Dispatcher.new(
      participant: participant, moment: :program_intake, day_number: 0
    ).send_text(body: Setting.fetch("program_intake_failed_text"))
  end
end
