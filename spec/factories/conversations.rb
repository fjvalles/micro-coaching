FactoryBot.define do
  factory :conversation do
    participant
    day_number { 1 }
    moment { :free_user }
    role { :user }
    body { "Hola" }
  end
end
