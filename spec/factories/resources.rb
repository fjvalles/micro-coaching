FactoryBot.define do
  factory :resource do
    sequence(:title) { |n| "Recurso #{n}" }
    sequence(:url) { |n| "https://example.com/recurso-#{n}" }
    kind { :article }
    status { :approved }
    source { :manual }
    topics { [ "foco" ] }
    last_verified_at { Time.current }

    trait :verified do
      status { :verified }
    end

    trait :pending do
      status { :pending }
      last_verified_at { nil }
    end
  end

  factory :resource_delivery do
    association :resource
    association :participant
    association :conversation
    moment { "free_assistant" }
  end
end
