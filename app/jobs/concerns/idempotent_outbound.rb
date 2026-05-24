module IdempotentOutbound
  extend ActiveSupport::Concern

  private

  # Returns true if the moment was already delivered OR is pending approval for today.
  # Prevents duplicate sends when Sidekiq retries or cron fires twice in the same hour.
  def already_handled?(participant:, moment:, day_number:)
    today_start = participant.local_time.beginning_of_day

    sent = participant.conversations.kept
                      .where(moment: moment, day_number: day_number)
                      .where("created_at >= ?", today_start)
                      .exists?

    pending = PendingResponse.kept
                             .where(participant: participant, moment: moment.to_s, day_number: day_number)
                             .where("created_at >= ?", today_start)
                             .where(status: %w[pending approved])
                             .exists?

    sent || pending
  end
end
