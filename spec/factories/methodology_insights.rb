FactoryBot.define do
  factory :methodology_insight do
    scope        { "phase_kpi" }
    payload      { {} }
    generated_at { Time.current }
    program      { nil }
  end
end
