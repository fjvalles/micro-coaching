require "rails_helper"

RSpec.describe AdvanceDayJob, type: :job do
  it "advances participants with completed checkin" do
    p = create(:participant, current_day: 5, status: :active)
    create(:conversation, participant: p, moment: :checkin_response, day_number: 5,
           role: :user, created_at: Time.current)

    described_class.new.perform
    expect(p.reload.current_day).to eq(6)
  end

  it "does not advance participants without checkin" do
    p = create(:participant, current_day: 5, status: :active)
    described_class.new.perform
    expect(p.reload.current_day).to eq(5)
  end
end
