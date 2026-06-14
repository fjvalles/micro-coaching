module Admin
  # Server capacity dashboard: Sidekiq queue health, DB pool, Redis memory.
  # Complements Sentry (which covers errors) by surfacing saturation before it
  # turns into failures. Read-only.
  class HealthController < BaseController
    before_action :require_superadmin
    def show
      @snapshot          = Ops::CapacitySnapshot.new.call
      @latency_threshold = Setting.fetch("capacity_queue_latency_alert_seconds").to_i
      @backlog_threshold = Setting.fetch("capacity_backlog_alert_threshold").to_i

      @latency_breached = @latency_threshold.positive? && @snapshot.max_latency > @latency_threshold
      @backlog_breached = @backlog_threshold.positive? && @snapshot.backlog > @backlog_threshold
    end
  end
end
