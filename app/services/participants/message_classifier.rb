module Participants
  class MessageClassifier
    Result = Struct.new(:type, :reason, keyword_init: true)

    CHECKIN_WINDOW = (20..23).freeze

    def initialize(participant:, now: Time.current)
      @participant = participant
      @now = now
    end

    def classify
      return Result.new(type: :initial_pattern_answer, reason: "no pattern recorded yet") if needs_initial_pattern?
      return Result.new(type: :checkin_response, reason: "in checkin window with pending checkin") if checkin_pending?
      Result.new(type: :free_user, reason: "default")
    end

    private

    def needs_initial_pattern?
      @participant.initial_pattern.blank? && @participant.conversations.kept.where(moment: :welcome).exists?
    end

    def checkin_pending?
      local = @participant.local_time(@now)
      return false unless CHECKIN_WINDOW.cover?(local.hour)

      pending = @participant.pending_checkin_at.present? &&
                @participant.pending_checkin_at.to_date == local.to_date

      already_answered = @participant.conversations.kept
                          .where(moment: :checkin_response, day_number: @participant.current_day)
                          .exists?

      pending && !already_answered
    end
  end
end
