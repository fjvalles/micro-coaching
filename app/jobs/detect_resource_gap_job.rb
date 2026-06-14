class DetectResourceGapJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    return unless Setting.fetch("resource_autodiscovery_enabled")

    conversation = Conversation.kept.find_by(id: conversation_id)
    return unless conversation
    return if ResourceDelivery.exists?(conversation_id: conversation.id)

    text = conversation.body.presence || conversation.transcription
    return if text.blank?

    result = Resources::GapDetector.new(participant: conversation.participant, text: text).call
    return unless result.needed?
    return if Resource.kept.where("topics @> ?", [ result.topic ].to_json).exists?

    found = Resources::Finder.new(
      topic: result.topic,
      kind: result.kind,
      program: conversation.participant.program,
      source: :gap_detection
    ).call
    found.resources.each { |resource| Resources::Verifier.new(resource: resource, topic: result.topic).call }
  end
end
