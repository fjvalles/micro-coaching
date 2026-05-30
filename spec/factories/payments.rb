FactoryBot.define do
  factory :payment do
    amount { 15_000 }
    sequence(:buy_order) { |n| "IMP-TEST-#{n}" }
    status { :pending }
  end
end
