require "rails_helper"

RSpec.describe CapacityAlertJob, type: :job do
  before do
    Setting.set("capacity_queue_latency_alert_seconds", 120)
    Setting.set("capacity_backlog_alert_threshold", 1000)
  end

  def snapshot(queues: [], enqueued: 0, retry_count: 0)
    Ops::CapacitySnapshot::Result.new(
      sidekiq: { enqueued: enqueued, retry: retry_count },
      queues: queues, db_pool: {}, redis: nil, redis_error: nil
    )
  end

  it "is a no-op when both thresholds are disabled" do
    Setting.set("capacity_queue_latency_alert_seconds", 0)
    Setting.set("capacity_backlog_alert_threshold", 0)
    expect(Ops::CapacitySnapshot).not_to receive(:new)
    described_class.new.perform
  end

  it "does not alert when within thresholds" do
    allow_any_instance_of(Ops::CapacitySnapshot).to receive(:call)
      .and_return(snapshot(queues: [ { name: "default", size: 5, latency: 3.0 } ], enqueued: 5))
    expect(Rails.logger).not_to receive(:warn)
    described_class.new.perform
  end

  it "warns when a queue latency exceeds the threshold" do
    allow_any_instance_of(Ops::CapacitySnapshot).to receive(:call)
      .and_return(snapshot(queues: [ { name: "default", size: 9, latency: 300.0 } ]))
    expect(Rails.logger).to receive(:warn).with(/latencia 300s > 120s/)
    described_class.new.perform
  end

  it "warns when the backlog exceeds the threshold" do
    allow_any_instance_of(Ops::CapacitySnapshot).to receive(:call)
      .and_return(snapshot(enqueued: 900, retry_count: 200))
    expect(Rails.logger).to receive(:warn).with(/backlog 1100 > 1000/)
    described_class.new.perform
  end
end
