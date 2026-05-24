FactoryBot.define do
  factory :day_content do
    association :program
    sequence(:day_number) { |n| ((n - 1) % 14) + 1 }
    phase { :see }
    title { "Test Day" }
    morning_template { "Buen día, {name}" }
    iareto_text { "Reto del día" }
    checkin_questions { "1. P1\n2. P2\n3. P3" }
    ai_system_prompt { "Sistema de prueba." }
    template_name_whatsapp { "despertar_dia_01" }
    active { true }
  end
end
