require "rails_helper"

RSpec.describe Subscription, type: :model do
  before do
    Setting.set("tax_rate", 0.19)
    Setting.set("payment_commission_rate", 0.0149)
  end

  it { is_expected.to define_enum_for(:status).with_values(pending: 0, active: 1, past_due: 2, canceled: 3, paused: 4) }
  it { is_expected.to validate_numericality_of(:billing_interval_days).is_greater_than(0) }

  describe ".billable" do
    it "includes active subs whose next charge is due" do
      due = create(:subscription, status: :active, next_billing_at: 1.hour.ago)
      create(:subscription, status: :active, next_billing_at: 2.days.from_now)
      create(:subscription, status: :past_due, next_billing_at: 1.hour.ago)

      expect(Subscription.billable).to contain_exactly(due)
    end

    it "excludes discarded subscriptions" do
      sub = create(:subscription, status: :active, next_billing_at: 1.hour.ago)
      sub.discard
      expect(Subscription.billable).to be_empty
    end
  end

  describe "#schedule_next_cycle!" do
    it "advances the cycle, resets failed attempts and stamps last_billed_at" do
      sub = create(:subscription, billing_interval_days: 30, billing_cycle_count: 1, failed_attempts: 2)

      sub.schedule_next_cycle!

      expect(sub.billing_cycle_count).to eq(2)
      expect(sub.failed_attempts).to eq(0)
      expect(sub.next_billing_at).to be_within(1.minute).of(30.days.from_now)
      expect(sub.last_billed_at).to be_present
    end
  end

  describe "#record_charge!" do
    it "creates an authorized Payment linked to the subscription with a commission snapshot" do
      sub = create(:subscription, amount_clp: 100_000)
      result = Webpay::OneclickClient::ChargeResult.new(
        success: true, authorized: true, status: "AUTHORIZED", amount: 100_000,
        authorization_code: "123", payment_type_code: "VN", response_code: 0, installments: 0, raw: {}
      )

      payment = sub.record_charge!(buy_order: "SUB-1", result: result)

      expect(payment).to be_authorized
      expect(payment.subscription).to eq(sub)
      expect(payment.amount).to eq(100_000)
      expect(payment.commission_amount).to eq(1_773) # 100000 * 0.0149 * 1.19, rounded
    end
  end
end
