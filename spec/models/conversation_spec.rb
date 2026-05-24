require "rails_helper"

RSpec.describe Conversation, type: :model do
  it { is_expected.to belong_to(:participant) }
  it { is_expected.to define_enum_for(:role).with_values(user: 0, assistant: 1, system: 2) }

  it "scope failed" do
    p = create(:participant)
    ok = create(:conversation, participant: p)
    bad = create(:conversation, participant: p, error_message: "fail")
    expect(Conversation.failed).to include(bad)
    expect(Conversation.failed).not_to include(ok)
  end

  it "discard works" do
    c = create(:conversation)
    c.discard
    expect(Conversation.kept).not_to include(c)
  end
end
