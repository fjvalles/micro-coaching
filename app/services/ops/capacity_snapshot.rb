require "sidekiq/api"

module Ops
  # Point-in-time capacity snapshot of the background-processing stack: Sidekiq
  # queue depth/latency, ActiveRecord connection pool, and Redis memory. Read-only.
  # Each section degrades gracefully (returns nil / empty) if Redis is unreachable,
  # so the admin Health page renders even when the worker host is down.
  #
  # Shared by Admin::HealthController (dashboard) and CapacityAlertJob (thresholds)
  # so the collection logic lives in one place.
  class CapacitySnapshot
    Result = Struct.new(:sidekiq, :queues, :db_pool, :redis, :redis_error, keyword_init: true) do
      # Total work waiting to run (enqueued now + scheduled retries).
      def backlog
        sidekiq.fetch(:enqueued, 0).to_i + sidekiq.fetch(:retry, 0).to_i
      end

      # Worst queue latency in seconds (0 when no queues / Redis down).
      def max_latency
        queues.map { |q| q[:latency].to_f }.max || 0.0
      end

      # True only when the core Sidekiq stats could not be read — i.e. Redis is
      # genuinely unreachable. A failure isolated to the Redis-memory probe does
      # NOT count as down (Sidekiq still answered), so the dashboard doesn't cry
      # wolf when only the optional memory metric is missing.
      def sidekiq_down?
        sidekiq.blank?
      end
    end

    def call
      stats  = sidekiq_stats
      queues = queue_stats
      Result.new(
        sidekiq:     stats,
        queues:      queues,
        db_pool:     db_pool_stats,
        redis:       redis_info,
        redis_error: @redis_error
      )
    end

    private

    def sidekiq_stats
      s = Sidekiq::Stats.new
      {
        enqueued:       s.enqueued,
        scheduled:      s.scheduled_size,
        retry:          s.retry_size,
        dead:           s.dead_size,
        processed:      s.processed,
        failed:         s.failed,
        busy:           Sidekiq::Workers.new.size,
        processes:      Sidekiq::ProcessSet.new.size
      }
    rescue StandardError => e
      @redis_error = e.message
      {}
    end

    def queue_stats
      Sidekiq::Queue.all.map do |q|
        { name: q.name, size: q.size, latency: q.latency }
      end
    rescue StandardError => e
      @redis_error ||= e.message
      []
    end

    def db_pool_stats
      ActiveRecord::Base.connection_pool.stat
    rescue StandardError
      {}
    end

    # Pulls Redis memory figures out of `INFO`. nil if Redis is unreachable.
    #
    # NOTE: Sidekiq 7 yields a redis-client connection wrapped in its compat
    # layer, whose `#info` takes NO arguments and returns the full INFO already
    # parsed into a string-keyed Hash. Passing a section (e.g. `c.info("memory")`)
    # raises ArgumentError — the bug that previously masqueraded as "Redis down".
    def redis_info
      raw = Sidekiq.redis(&:info)
      {
        used_memory_human:      raw["used_memory_human"],
        used_memory_peak_human: raw["used_memory_peak_human"],
        maxmemory_human:        raw["maxmemory_human"]
      }
    rescue StandardError => e
      @redis_error ||= e.message
      nil
    end
  end
end
