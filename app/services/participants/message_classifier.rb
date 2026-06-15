module Participants
  class MessageClassifier
    Result = Struct.new(:type, :reason, keyword_init: true)

    def initialize(participant:, now: Time.current)
      @participant = participant
      @now = now
    end

    def classify
      return Result.new(type: :program_intake, reason: "personalized program intake in progress") if @participant.intake?
      return Result.new(type: :initial_pattern_answer, reason: "no pattern recorded yet") if needs_initial_pattern?
      return Result.new(type: :checkin_response, reason: "in checkin window with pending checkin") if checkin_pending?
      Result.new(type: :free_user, reason: "default")
    end

    private

    def needs_initial_pattern?
      @participant.initial_pattern.blank? && @participant.conversations.kept.where(moment: :welcome).exists?
    end

    def checkin_pending?
      @participant.unresolved_checkin_pending?
    end
  end
end
