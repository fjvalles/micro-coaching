FactoryBot.define do
  factory :daily_report do
    participant
    day_number { 1 }
    raw_text { "Hoy noté X." }
    ai_summary { "Resumen breve." }
    ai_key_pattern { "Patrón clave" }
    reported_at { Time.current }
  end
end
