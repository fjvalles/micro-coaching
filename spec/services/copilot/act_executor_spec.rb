require "rails_helper"

RSpec.describe Copilot::ActExecutor do
  let(:admin) { create(:admin_user, superadmin: true) }
  let(:session) { admin.copilot_sessions.create!(status: :active) }
  let(:participant) { create(:participant, status: :active) }

  def pending(tool, args)
    session.copilot_pending_actions.create!(tool_name: tool, args: args, status: :pending)
  end

  describe "send_message" do
    it "executes through Outbound::AdminMessage and marks executed" do
      allow_any_instance_of(Outbound::AdminMessage).to receive(:call)
        .and_return(Outbound::AdminMessage::Result.new(sent: true, conversation: nil))

      action = pending("send_message", { "participant_id" => participant.id, "body" => "Hola" })
      result = described_class.new(action).call

      expect(result.ok?).to be(true)
      expect(action.reload).to be_executed
      expect(session.copilot_messages.where(role: :assistant).last.content).to include("mensaje enviado")
    end

    it "marks failed when the send is rejected" do
      allow_any_instance_of(Outbound::AdminMessage).to receive(:call)
        .and_return(Outbound::AdminMessage::Result.new(sent: false, skipped_reason: :outside_24h_window))

      action = pending("send_message", { "participant_id" => participant.id, "body" => "Hola" })
      result = described_class.new(action).call

      expect(result.ok?).to be(false)
      expect(action.reload).to be_failed
    end

    it "rejects an unknown participant id without calling the service" do
      expect(Outbound::AdminMessage).not_to receive(:new)
      action = pending("send_message", { "participant_id" => "nope", "body" => "Hola" })
      described_class.new(action).call
      expect(action.reload).to be_failed
    end

    it "rejects an over-long body" do
      action = pending("send_message", { "participant_id" => participant.id, "body" => "x" * 2000 })
      described_class.new(action).call
      expect(action.reload).to be_failed
    end
  end

  describe "pause / reactivate" do
    it "pauses an active participant" do
      action = pending("pause_participant", { "participant_id" => participant.id })
      described_class.new(action).call
      expect(participant.reload).to be_paused
      expect(action.reload).to be_executed
    end

    it "reactivates a paused participant" do
      participant.update!(status: :paused)
      action = pending("reactivate_participant", { "participant_id" => participant.id })
      described_class.new(action).call
      expect(participant.reload).to be_active
    end
  end

  it "refuses to run an action that is not pending" do
    action = pending("pause_participant", { "participant_id" => participant.id })
    action.update!(status: :executed)
    result = described_class.new(action).call
    expect(result.ok?).to be(false)
  end
end
