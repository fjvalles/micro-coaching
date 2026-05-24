FactoryBot.define do
  factory :prompt_template do
    sequence(:key) { |n| "test_prompt_#{n}" }
    name { "Test prompt" }
    current_body { "You are a helpful assistant." }
    current_version { 0 }
    source { "service" }
  end

  factory :prompt_version do
    association :prompt_template
    sequence(:version) { |n| n }
    body { "system body" }
    origin { "service" }
  end

  factory :prompt_execution do
    association :prompt_template
    association :prompt_version
    day_number { 1 }
    moment { "morning_wake" }
    rendered_messages { [ { role: "system", content: "hi" } ] }
    output_body { "ok" }
    tokens_input { 10 }
    tokens_output { 20 }
  end
end
