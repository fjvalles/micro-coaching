require "rails_helper"

RSpec.describe ParticipantMailer, type: :mailer do
  it "builds the magic-link email to the participant" do
    participant = create(:participant, email: "user@example.com", name: "Ana")
    token = participant.generate_token_for(:portal_login)

    mail = described_class.magic_link(participant.id, token)

    expect(mail.to).to eq([ "user@example.com" ])
    expect(mail.subject).to include("acceso")
    expect(mail.body.encoded).to include("/portal/sesion/")
  end

  it "does not deliver when the participant has no email" do
    participant = create(:participant, email: nil)
    mail = described_class.magic_link(participant.id, "tok")
    expect(mail.to).to be_blank
  end
end
