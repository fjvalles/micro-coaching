FactoryBot.define do
  factory :skill_detection do
    association :participant
    association :skill
    conversation { association :conversation, participant: participant }
    confidence { 0.8 }
    source { "free_user" }
    detected_at { Time.current }
  end
end
