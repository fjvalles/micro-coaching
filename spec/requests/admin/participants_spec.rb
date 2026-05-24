require "rails_helper"

RSpec.describe "Admin::Participants", type: :request do
  include Warden::Test::Helpers
  include ActiveJob::TestHelper

  let(:admin) { create(:admin_user) }
  let(:program) { create(:program) }
  let!(:participant) { create(:participant, program: program, status: :pending) }

  before { login_as(admin, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /admin/participants" do
    let!(:other_program) { create(:program) }
    let!(:other_participant) { create(:participant, name: "Excluded Participant", program: other_program, status: :active, current_day: 5) }

    it "lists participants" do
      get "/admin/participants"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).to include(other_participant.name)
      expect(response.body).to include("Nuevo participante")
    end

    it "filters by program_id" do
      get "/admin/participants", params: { program_id: program.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).not_to include(other_participant.name)
    end

    it "filters by current_day" do
      get "/admin/participants", params: { current_day: 5 }
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(participant.name)
      expect(response.body).to include(other_participant.name)
    end
  end

  describe "GET /admin/participants/:id" do
    it "renders the detail page" do
      get "/admin/participants/#{participant.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.name)
      expect(response.body).to include(participant.phone_e164)
    end
  end

  describe "POST /admin/participants" do
    it "creates a new participant" do
      expect {
        post "/admin/participants", params: {
          participant: {
            program_id: program.id,
            name: "Nuevo Test Participant",
            phone_e164: "+521999988877",
            status: "pending",
            timezone: "America/Mexico_City"
          }
        }
      }.to change(Participant, :count).by(1)

      new_participant = Participant.find_by(phone_e164: "+521999988877")
      expect(response).to redirect_to(admin_participant_path(new_participant))
    end
  end

  describe "POST /admin/participants/:id/enroll" do
    it "enrolls a pending participant and enqueues SendWelcomeJob" do
      expect {
        post "/admin/participants/#{participant.id}/enroll"
      }.to have_enqueued_job(SendWelcomeJob).with(participant.id)

      participant.reload
      expect(participant.status.to_sym).to eq(:active)
      expect(participant.current_day).to eq(1)
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end

  describe "POST /admin/participants/:id/discard" do
    it "soft-deletes the participant" do
      post "/admin/participants/#{participant.id}/discard"
      participant.reload
      expect(participant.discarded?).to be_truthy
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end

  describe "POST /admin/participants/:id/undiscard" do
    before { participant.discard }

    it "restores the soft-deleted participant" do
      post "/admin/participants/#{participant.id}/undiscard"
      participant.reload
      expect(participant.discarded?).to be_falsey
      expect(response).to redirect_to(admin_participant_path(participant))
    end
  end
end
