FactoryBot.define do
  factory :subscription do
    participant
    status { :active }
    plan { "monthly" }
    amount_clp { 15_000 }
    tbk_user { "tbk-user-token" }
    tbk_username { "user-abc" }
    billing_interval_days { 30 }
    next_billing_at { 30.days.from_now }
    billing_cycle_count { 1 }
  end
end
