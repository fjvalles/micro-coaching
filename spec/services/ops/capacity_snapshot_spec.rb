require "rails_helper"

RSpec.describe Ops::CapacitySnapshot do
  describe "#call" do
    it "returns DB pool stats even when Redis is unreachable" do
      allow(Sidekiq::Stats).to receive(:new).and_raise(Redis::CannotConnectError, "down")
      allow(Sidekiq::Queue).to receive(:all).and_raise(Redis::CannotConnectError, "down")
      allow(Sidekiq).to receive(:redis).and_raise(Redis::CannotConnectError, "down")

      result = described_class.new.call

      expect(result.sidekiq).to eq({})
      expect(result.queues).to eq([])
      expect(result.redis).to be_nil
      expect(result.redis_error).to be_present
      expect(result.db_pool).to include(:size) # AR pool still readable
      expect(result.sidekiq_down?).to be(true) # core stats failed → genuine outage
    end

    it "reads Redis memory via the no-arg compat #info (guards the section-arg regression)" do
      # Sidekiq 7 yields a redis-client wrapped in a compat layer whose #info
      # takes NO arguments. Passing a section (`c.info("memory")`) raises
      # ArgumentError, which previously got mislabeled as "Redis down".
      stats = instance_double(
        Sidekiq::Stats, enqueued: 0, scheduled_size: 0, retry_size: 0, dead_size: 0,
        processed: 1, failed: 0
      )
      allow(Sidekiq::Stats).to receive(:new).and_return(stats)
      allow(Sidekiq::Workers).to receive(:new).and_return(instance_double(Sidekiq::Workers, size: 0))
      allow(Sidekiq::ProcessSet).to receive(:new).and_return(instance_double(Sidekiq::ProcessSet, size: 1))
      allow(Sidekiq::Queue).to receive(:all).and_return([])

      fake_client = Class.new do
        # 0-arity, matching the compat layer; an arg would raise ArgumentError.
        def info
          { "used_memory_human" => "3M", "used_memory_peak_human" => "5M", "maxmemory_human" => "0B" }
        end
      end.new
      allow(Sidekiq).to receive(:redis) { |&blk| blk.call(fake_client) }

      result = described_class.new.call

      expect(result.redis_error).to be_nil
      expect(result.redis[:used_memory_human]).to eq("3M")
      expect(result.sidekiq_down?).to be(false)
    end

    it "computes backlog and max_latency from collected data" do
      stats = instance_double(
        Sidekiq::Stats, enqueued: 10, scheduled_size: 0, retry_size: 5, dead_size: 0,
        processed: 100, failed: 2
      )
      allow(Sidekiq::Stats).to receive(:new).and_return(stats)
      allow(Sidekiq::Workers).to receive(:new).and_return(instance_double(Sidekiq::Workers, size: 1))
      allow(Sidekiq::ProcessSet).to receive(:new).and_return(instance_double(Sidekiq::ProcessSet, size: 1))
      q1 = instance_double(Sidekiq::Queue, name: "default", size: 10, latency: 4.0)
      q2 = instance_double(Sidekiq::Queue, name: "mailers", size: 1, latency: 42.0)
      allow(Sidekiq::Queue).to receive(:all).and_return([ q1, q2 ])
      allow(Sidekiq).to receive(:redis).and_return({ "used_memory_human" => "2M" })

      result = described_class.new.call

      expect(result.backlog).to eq(15) # 10 enqueued + 5 retry
      expect(result.max_latency).to eq(42.0)
      expect(result.redis[:used_memory_human]).to eq("2M")
    end
  end
end
