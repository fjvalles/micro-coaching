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
