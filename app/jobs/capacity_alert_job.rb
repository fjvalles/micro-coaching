class CapacityAlertJob < ApplicationJob
  queue_as :default

  # Periodically checks background-processing capacity and raises a Sentry warning
  # when a queue is backing up. Thresholds are Settings (0 = that check off), so the
  # alert can be tuned without a deploy. Read-only: never mutates queues. Idempotent
  # — re-running just re-evaluates the current snapshot.
  def perform
    latency_threshold = Setting.fetch("capacity_queue_latency_alert_seconds").to_i
    backlog_threshold = Setting.fetch("capacity_backlog_alert_threshold").to_i
    return if latency_threshold.zero? && backlog_threshold.zero?

    snapshot = Ops::CapacitySnapshot.new.call
    breaches = []

    if latency_threshold.positive?
      snapshot.queues.each do |q|
        next unless q[:latency].to_f > latency_threshold

        breaches << "cola '#{q[:name]}' latencia #{q[:latency].round}s > #{latency_threshold}s"
      end
    end

    if backlog_threshold.positive? && snapshot.backlog > backlog_threshold
      breaches << "backlog #{snapshot.backlog} > #{backlog_threshold}"
    end

    return if breaches.empty?

    message = "[Capacity] #{breaches.join('; ')}"
    Rails.logger.warn(message)
    return unless defined?(Sentry) && Sentry.respond_to?(:capture_message)

    Sentry.capture_message(message, level: :warning)
  end
end
