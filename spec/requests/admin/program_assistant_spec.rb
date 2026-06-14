require "rails_helper"

RSpec.describe "Admin::ProgramAssistant", type: :request do
  include Warden::Test::Helpers

  let(:admin) { create(:admin_user, name: "Admin") }

  before { Setting.set("program_assistant_enabled", true) }
  after  { Warden.test_reset! }

  def login(user) = login_as(user, scope: :admin_user)

  describe "kill-switch" do
    it "forbids when program_assistant_enabled is off" do
      Setting.set("program_assistant_enabled", false)
      login(admin)
      get "/admin/program_assistant"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "programs index integration" do
    before { login(admin) }

    it "shows the Asistente IA button and modal frame when enabled" do
      get "/admin/programs"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Asistente IA")
      expect(response.body).to include("program_assistant_frame")
      expect(response.body).to include(admin_program_assistant_path)
    end

    it "hides the button when the kill-switch is off" do
      Setting.set("program_assistant_enabled", false)
      get "/admin/programs"
      expect(response.body).not_to include("Asistente IA")
    end
  end

  describe "show" do
    before { login(admin) }

    it "renders the chat frame and reuses/creates one active session" do
      expect { get "/admin/program_assistant" }
        .to change(ProgramAssistantSession, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("program_assistant_frame")

      # second visit reuses the same open session
      expect { get "/admin/program_assistant" }
        .not_to change(ProgramAssistantSession, :count)
    end
  end

  describe "message" do
    before { login(admin) }

    it "persists the user turn and enqueues the agent job" do
      get "/admin/program_assistant" # creates session
      session = admin.program_assistant_sessions.active.last
      expect {
        post "/admin/program_assistant/message", params: { content: "Quiero un programa de 7 días" }
      }.to change { session.program_assistant_messages.count }.by(1)
        .and have_enqueued_job(ProgramAssistantAgentJob).with(session.id)
    end

    it "ignores a blank message" do
      get "/admin/program_assistant"
      session = admin.program_assistant_sessions.active.last
      expect {
        post "/admin/program_assistant/message", params: { content: "  " }
      }.not_to change { session.program_assistant_messages.count }
    end
  end

  describe "reset" do
    before { login(admin) }

    it "archives the open session" do
      get "/admin/program_assistant"
      session = admin.program_assistant_sessions.active.last
      post "/admin/program_assistant/reset"
      expect(session.reload).to be_archived
    end
  end

  describe "pending actions" do
    before { login(admin) }

    it "runs the executor on approve" do
      session = admin.program_assistant_sessions.create!(status: :active)
      action = session.program_assistant_pending_actions.create!(
        tool_name: "create_program",
        args: { "name" => "Demo", "total_days" => 1,
                "days" => [ { "day_number" => 1, "phase" => "see", "title" => "Día 1" } ] },
        status: :pending
      )

      expect { post "/admin/program_assistant/actions/#{action.id}/approve" }
        .to change(Program, :count).by(1)
      expect(action.reload).to be_executed
      expect(action.approved_by).to eq(admin.email)
    end

    it "rejects an action without executing it" do
      session = admin.program_assistant_sessions.create!(status: :active)
      action = session.program_assistant_pending_actions.create!(tool_name: "update_program", args: {}, status: :pending)
      post "/admin/program_assistant/actions/#{action.id}/reject"
      expect(action.reload).to be_rejected
    end

    it "forbids approving an action from another admin's session" do
      other = create(:admin_user, name: "Other", email: "other@example.com")
      foreign = other.program_assistant_sessions.create!(status: :active)
      action = foreign.program_assistant_pending_actions.create!(tool_name: "create_program", args: {})
      post "/admin/program_assistant/actions/#{action.id}/approve"
      expect(response).to have_http_status(:forbidden)
      expect(action.reload).to be_pending
    end
  end
end
