require "rails_helper"

RSpec.describe SubscriptionBillingJob, type: :job do
  before do
    Setting.set("webpay_oneclick_enabled", true)
    Setting.set("subscription_max_retries", 3)
    Setting.set("tax_rate", 0.19)
    Setting.set("payment_commission_rate", 0.0149)
  end

  let(:authorized) do
    Webpay::OneclickClient::ChargeResult.new(
      success: true, authorized: true, status: "AUTHORIZED", amount: 15_000, buy_order: "B",
      authorization_code: "A", payment_type_code: "VN", response_code: 0, installments: 0, raw: {}
    )
  end
  let(:declined) do
    Webpay::OneclickClient::ChargeResult.new(success: true, authorized: false, status: "FAILED", response_code: -1, raw: {})
  end

  it "does nothing when the kill-switch is off" do
    Setting.set("webpay_oneclick_enabled", false)
    create(:subscription, status: :active, next_billing_at: 1.hour.ago)
    expect_any_instance_of(Webpay::OneclickClient).not_to receive(:charge)

    described_class.new.perform
  end

  it "charges a due subscription, records a payment and advances the cycle" do
    sub = create(:subscription, status: :active, next_billing_at: 1.hour.ago, amount_clp: 15_000, billing_cycle_count: 1)
    allow_any_instance_of(Webpay::OneclickClient).to receive(:charge).and_return(authorized)

    expect { described_class.new.perform }.to change(Payment, :count).by(1)

    sub.reload
    expect(sub.billing_cycle_count).to eq(2)
    expect(sub.next_billing_at).to be > Time.current
    expect(Payment.last.subscription).to eq(sub)
  end

  it "does not charge a subscription that is not yet due" do
    create(:subscription, status: :active, next_billing_at: 2.days.from_now)
    expect_any_instance_of(Webpay::OneclickClient).not_to receive(:charge)

    expect { described_class.new.perform }.not_to change(Payment, :count)
  end

  it "reschedules and counts a failed charge" do
    sub = create(:subscription, status: :active, next_billing_at: 1.hour.ago, failed_attempts: 0)
    allow_any_instance_of(Webpay::OneclickClient).to receive(:charge).and_return(declined)

    described_class.new.perform

    sub.reload
    expect(sub.failed_attempts).to eq(1)
    expect(sub).to be_active
    expect(sub.next_billing_at).to be > Time.current
  end

  it "flags past_due after exceeding the retry limit" do
    sub = create(:subscription, status: :active, next_billing_at: 1.hour.ago, failed_attempts: 3)
    allow_any_instance_of(Webpay::OneclickClient).to receive(:charge).and_return(declined)

    described_class.new.perform

    expect(sub.reload).to be_past_due
  end
end
