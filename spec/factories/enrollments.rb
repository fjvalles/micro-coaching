FactoryBot.define do
  factory :enrollment do
    association :participant
    association :program
    cycle_number { 1 }
    status { :active }
    started_at { Time.current }
  end
end
