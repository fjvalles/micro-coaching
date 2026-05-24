FactoryBot.define do
  factory :participant do
    association :program
    sequence(:name) { |n| "Participante #{n}" }
    sequence(:phone_e164) { |n| "+5215555000#{n.to_s.rjust(3, '0')}" }
    status { :active }
    current_day { 1 }
    timezone { "America/Santiago" }
    enrolled_at { Time.current }
    started_at { Time.current }
  end
end
