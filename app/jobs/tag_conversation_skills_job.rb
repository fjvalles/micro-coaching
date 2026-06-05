class TagConversationSkillsJob < ApplicationJob
  queue_as :default

  # Detects the participant's human skills surfacing in one inbound conversation
  # and persists them as SkillDetection rows. Runs async so it never adds latency
  # to the participant's reply. Idempotent: a conversation that already has
  # detections is skipped, and the unique [conversation_id, skill_id] index guards
  # against duplicate webhook re-delivery.
  def perform(conversation_id)
    return unless Setting.fetch("skill_tagging_enabled")

    conversation = Conversation.kept.find_by(id: conversation_id)
    return unless conversation
    return if SkillDetection.exists?(conversation_id: conversation.id)

    participant = conversation.participant
    text = conversation.body.presence || conversation.transcription
    return if text.blank?

    result = Openai::SkillTagger.new(participant: participant, text: text).call
    min_confidence = Setting.fetch("skill_tagging_min_confidence").to_f

    result.tags.each do |tag|
      next if tag.confidence && tag.confidence < min_confidence

      skill = Skill.active.find_by(slug: tag.slug)
      next unless skill

      SkillDetection.create!(
        participant: participant,
        conversation: conversation,
        skill: skill,
        confidence: tag.confidence,
        source: conversation.moment,
        detected_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      next # concurrent/duplicate delivery already recorded this detection
    end
  end
end
