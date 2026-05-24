FactoryBot.define do
  factory :program do
    sequence(:name) { |n| "Programa #{n}" }
    sequence(:slug) { |n| "programa-#{n}" }
    description { "Programa de prueba" }
    manifesto   { "Eres un coach de prueba. Sé breve." }
    total_days  { 14 }
    active      { true }
  end
end
