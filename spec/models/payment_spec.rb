require "rails_helper"

RSpec.describe Payment, type: :model do
  before do
    Setting.set("tax_rate", 0.19)
    Setting.set("payment_commission_rate", 0.0149)
  end

  it { is_expected.to validate_presence_of(:buy_order) }
  it { is_expected.to define_enum_for(:status).with_values(pending: 0, authorized: 1, rejected: 2, failed: 3, aborted: 4, refunded: 5) }
  it { is_expected.to define_enum_for(:purpose).with_values(membership: 0, personalized: 1) }

  it "defaults purpose to membership" do
    expect(build(:payment).purpose).to eq("membership")
  end

  it "validates buy_order uniqueness" do
    create(:payment, buy_order: "DUP")
    expect(build(:payment, buy_order: "DUP")).not_to be_valid
  end

  describe "#tax_amount / #net_of_tax" do
    it "extracts IVA from an IVA-included gross amount" do
      p = build(:payment, amount: 11_900)
      expect(p.tax_amount(0.19)).to eq(1_900)
      expect(p.net_of_tax(0.19)).to eq(10_000)
    end

    it "is zero for a zero amount" do
      expect(build(:payment, amount: 0).tax_amount(0.19)).to eq(0)
    end
  end

  describe "#assign_commission_snapshot!" do
    it "computes the Transbank commission (with IVA) and net received" do
      p = build(:payment, amount: 100_000)
      p.assign_commission_snapshot!
      # 100000 * 0.0149 = 1490; * 1.19 = 1773 (rounded)
      expect(p.commission_amount).to eq(1_773)
      expect(p.net_amount).to eq(100_000 - 1_773)
    end
  end

  it ".next_buy_order is prefixed and unique-ish" do
    expect(Payment.next_buy_order).to start_with("IMP-")
    expect(Payment.next_buy_order).not_to eq(Payment.next_buy_order)
  end

  describe "scopes" do
    it ".income returns only authorized payments" do
      auth = create(:payment, status: :authorized)
      create(:payment, status: :pending)
      expect(Payment.income).to contain_exactly(auth)
    end
  end
end
