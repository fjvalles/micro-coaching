require "rails_helper"

RSpec.describe PromptTuningMailer, type: :mailer do
  it "sends proposal notifications to superadmins" do
    create(:admin_user, email: "ops@example.com", superadmin: true)
    run = create(:prompt_tuning_run, score: 61)

    mail = described_class.proposal(run.id)

    expect(mail.to).to eq([ "ops@example.com" ])
    expect(mail.subject).to include("score 61/100")
    expect(mail.body.encoded).to include("/admin/prompt_tuning/#{run.id}")
  end

  it "does not deliver when there is no admin recipient" do
    AdminUser.delete_all
    run = create(:prompt_tuning_run)

    mail = described_class.proposal(run.id)

    expect(mail.to).to be_blank
  end
end
