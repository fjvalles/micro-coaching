FactoryBot.define do
  factory :pending_response do
    association :participant
    mode { "approve" }
    moment { "free_assistant" }
    day_number { 1 }
    draft_body { "Borrador IA" }
    delivery_kind { "text" }
    status { "pending" }
  end
end
