require "rails_helper"

RSpec.describe "Admin::Copilot", type: :request do
  include Warden::Test::Helpers

  let(:superadmin) { create(:admin_user, name: "Super", superadmin: true) }
  let(:regular)    { create(:admin_user, name: "Regular", email: "reg@example.com") }

  before { Setting.set("copilot_enabled", true) }
  after  { Warden.test_reset! }

  def login(user)
    login_as(user, scope: :admin_user)
  end

  describe "superadmin gate" do
    it "forbids a non-superadmin even when the copilot is enabled" do
      login(regular)
      get "/admin/copilot"
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a superadmin" do
      login(superadmin)
      get "/admin/copilot"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "kill-switch" do
    it "redirects a superadmin to root when copilot_enabled is off" do
      Setting.set("copilot_enabled", false)
      login(superadmin)
      get "/admin/copilot"
      expect(response).to redirect_to(admin_root_path)
    end
  end

  describe "sessions" do
    before { login(superadmin) }

    it "renders a session transcript (turbo streams + partials)" do
      session = superadmin.copilot_sessions.create!(status: :active)
      session.copilot_messages.create!(role: :user, content: "hola")
      session.copilot_messages.create!(role: :assistant, content: "qué tal")
      get "/admin/copilot/sessions/#{session.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("qué tal")
    end

    it "creates a session and redirects to it" do
      expect {
        post "/admin/copilot/sessions"
      }.to change(CopilotSession, :count).by(1)
      expect(response).to redirect_to(admin_copilot_session_path(CopilotSession.last))
    end

    it "persists the user turn and enqueues the agent job on message" do
      session = superadmin.copilot_sessions.create!(status: :active)
      expect {
        post "/admin/copilot/sessions/#{session.id}/message", params: { content: "¿cuántos participantes activos?" }
      }.to change { session.copilot_messages.count }.by(1)
        .and have_enqueued_job(CopilotAgentJob).with(session.id)
      expect(session.copilot_messages.last.role).to eq("user")
    end

    it "ignores a blank message" do
      session = superadmin.copilot_sessions.create!(status: :active)
      expect {
        post "/admin/copilot/sessions/#{session.id}/message", params: { content: "  " }
      }.not_to change { session.copilot_messages.count }
    end

    it "scopes sessions to the current admin" do
      others = create(:admin_user, name: "Other", email: "other@example.com", superadmin: true)
      foreign = others.copilot_sessions.create!(status: :active)
      get "/admin/copilot/sessions/#{foreign.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "pending actions" do
    before { login(superadmin) }

    it "executes the wrapped service on approve" do
      allow_any_instance_of(Outbound::AdminMessage).to receive(:call)
        .and_return(Outbound::AdminMessage::Result.new(sent: true, conversation: nil))
      participant = create(:participant, status: :active)
      session = superadmin.copilot_sessions.create!(status: :active)
      action = session.copilot_pending_actions.create!(
        tool_name: "send_message",
        args: { "participant_id" => participant.id, "body" => "Hola" },
        status: :pending
      )

      post "/admin/copilot/actions/#{action.id}/approve"

      expect(action.reload).to be_executed
      expect(action.approved_by).to eq(superadmin.email)
    end

    it "rejects an action without executing it" do
      session = superadmin.copilot_sessions.create!(status: :active)
      action = session.copilot_pending_actions.create!(tool_name: "pause_participant", args: {}, status: :pending)
      post "/admin/copilot/actions/#{action.id}/reject"
      expect(action.reload).to be_rejected
    end

    it "forbids approving an action from another admin's session" do
      others = create(:admin_user, name: "Other", email: "other2@example.com", superadmin: true)
      foreign = others.copilot_sessions.create!(status: :active)
      action = foreign.copilot_pending_actions.create!(tool_name: "send_message", args: {})
      post "/admin/copilot/actions/#{action.id}/approve"
      expect(response).to have_http_status(:forbidden)
      expect(action.reload).to be_pending
    end
  end
end
