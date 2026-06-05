class SendAdminMessageJob < ApplicationJob
  queue_as :default

  # Per-participant async send for a broadcast. Mirrors the fan-out unit pattern
  # (one job per participant) so Meta rate limits are spread across the queue
  # instead of blocking a web request. Window/blank guards live in the service.
  def perform(participant_id, kind:, body: nil, template_name: nil, variables: [])
    participant = Participant.kept.find_by(id: participant_id)
    return unless participant

    Outbound::AdminMessage.new(
      participant: participant,
      kind: kind,
      body: body,
      template_name: template_name,
      variables: variables
    ).call
  end
end
