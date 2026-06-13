class RefreshParticipantSummaryJob < ApplicationJob
  queue_as :default

  # Refreshes the participant's rolling AI memory (Participant#ai_summary) after a
  # check-in. Runs async so it never adds latency to the participant's reply. Gated
  # by the participant_summary_enabled kill-switch. Safe to re-run (it overwrites).
  def perform(participant_id)
    return unless Setting.fetch("participant_summary_enabled")

    participant = Participant.kept.find_by(id: participant_id)
    return unless participant

    result = Openai::ParticipantSummarizer.new(participant: participant).call
    return if result.summary.blank?

    PaperTrail.request(whodunnit: "ai:ParticipantSummarizer", controller_info: { source: "ai" }) do
      participant.update!(ai_summary: result.summary, ai_summary_updated_at: Time.current)
    end
  end
end
