require "rails_helper"

RSpec.describe BroadcastMessageJob, type: :job do
  let!(:p1) { create(:participant) }
  let!(:p2) { create(:participant) }
  let!(:discarded) { create(:participant, discarded_at: Time.current) }

  it "fans out one SendAdminMessageJob per kept participant" do
    expect {
      described_class.new.perform([ p1.id, p2.id, discarded.id ], kind: "template", template_name: "t")
    }.to have_enqueued_job(SendAdminMessageJob).exactly(2).times
  end

  it "passes the message payload through to each child job" do
    expect {
      described_class.new.perform([ p1.id ], kind: "text", body: "Hola", variables: [])
    }.to have_enqueued_job(SendAdminMessageJob).with(p1.id, kind: "text", body: "Hola", template_name: nil, variables: [])
  end
end

RSpec.describe SendAdminMessageJob, type: :job do
  let(:participant) { create(:participant) }

  it "delegates to Outbound::AdminMessage" do
    fake = instance_double(Outbound::AdminMessage, call: nil)
    expect(Outbound::AdminMessage).to receive(:new).with(
      hash_including(participant: participant, kind: "text", body: "Hola")
    ).and_return(fake)

    described_class.new.perform(participant.id, kind: "text", body: "Hola")
  end

  it "no-ops for a missing participant" do
    expect(Outbound::AdminMessage).not_to receive(:new)
    described_class.new.perform("00000000-0000-0000-0000-000000000000", kind: "text", body: "Hola")
  end
end
