require "rails_helper"

RSpec.describe "Portal::Sessions", type: :request do
  describe "POST /portal/acceso" do
    it "sends a magic link when the email exists (case-insensitive)" do
      create(:participant, email: "user@example.com")
      expect {
        post portal_login_path, params: { email: "USER@example.com" }
      }.to have_enqueued_mail(ParticipantMailer, :magic_link)
      expect(response).to redirect_to(portal_login_path)
    end

    it "does not reveal a missing email — same response, no mail" do
      expect {
        post portal_login_path, params: { email: "nobody@example.com" }
      }.not_to have_enqueued_mail(ParticipantMailer, :magic_link)
      expect(response).to redirect_to(portal_login_path)
    end
  end

  describe "GET /portal/sesion/:token" do
    it "logs in with a valid token" do
      participant = create(:participant, email: "u@e.com")
      get portal_session_path(participant.generate_token_for(:portal_login))
      expect(response).to redirect_to(portal_root_path)
    end

    it "rejects an invalid token" do
      get portal_session_path("garbage-token")
      expect(response).to redirect_to(portal_login_path)
    end

    it "rejects a token after the email changed (invalidation)" do
      participant = create(:participant, email: "old@e.com")
      token = participant.generate_token_for(:portal_login)
      participant.update!(email: "new@e.com")
      get portal_session_path(token)
      expect(response).to redirect_to(portal_login_path)
    end
  end

  describe "DELETE /portal/salir" do
    it "clears the session" do
      participant = create(:participant, email: "u@e.com")
      get portal_session_path(participant.generate_token_for(:portal_login))
      delete portal_logout_path
      get portal_root_path
      expect(response).to redirect_to(portal_login_path)
    end
  end
end
