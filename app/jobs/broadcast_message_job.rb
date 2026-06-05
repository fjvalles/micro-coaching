class BroadcastMessageJob < ApplicationJob
  queue_as :default

  # Fans out a manual admin message to many participants, one SendAdminMessageJob
  # each (same pattern as MorningWakeJob → MorningWakeForParticipantJob). Keeps the
  # web request fast and lets each send retry/rate-limit independently.
  def perform(participant_ids, kind:, body: nil, template_name: nil, variables: [])
    Participant.kept.where(id: participant_ids).find_each do |participant|
      SendAdminMessageJob.perform_later(
        participant.id,
        kind: kind,
        body: body,
        template_name: template_name,
        variables: variables
      )
    end
  end
end
