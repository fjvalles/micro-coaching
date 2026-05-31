require "rails_helper"

RSpec.describe "Admin::Health", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user) }

  before do
    login_as(admin, scope: :admin_user)
    allow_any_instance_of(Ops::CapacitySnapshot).to receive(:call).and_return(
      Ops::CapacitySnapshot::Result.new(
        sidekiq: { enqueued: 3, scheduled: 0, retry: 1, dead: 0, processed: 50, failed: 0, busy: 1, processes: 1 },
        queues: [ { name: "default", size: 3, latency: 2.0 } ],
        db_pool: { size: 5, busy: 1, idle: 4, waiting: 0 },
        redis: { used_memory_human: "2M", used_memory_peak_human: "3M", maxmemory_human: "0B" },
        redis_error: nil
      )
    )
  end

  after { Warden.test_reset! }

  describe "GET /admin/health" do
    it "renders the capacity dashboard" do
      get admin_health_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Salud del sistema").and include("Backlog").and include("Colas Sidekiq")
    end

    it "shows a degraded banner when Redis is unreachable" do
      allow_any_instance_of(Ops::CapacitySnapshot).to receive(:call).and_return(
        Ops::CapacitySnapshot::Result.new(
          sidekiq: {}, queues: [], db_pool: { size: 5 }, redis: nil, redis_error: "Connection refused"
        )
      )
      get admin_health_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("no disponible")
    end

    it "requires admin authentication" do
      Warden.test_reset!
      get admin_health_path
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end
end
