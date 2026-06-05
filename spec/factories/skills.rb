FactoryBot.define do
  factory :skill do
    sequence(:slug) { |n| "habilidad_#{n}" }
    sequence(:name) { |n| "Habilidad #{n}" }
    sequence(:position) { |n| n }
    definition { "Definición de la habilidad." }
    importance { "Por qué importa en el trabajo." }
    trap { "Trampa frecuente." }
    one_liner { "Resumen en una frase." }
    signals { [ "Señal uno.", "Señal dos." ] }
    practices { [ "Práctica uno.", "Práctica dos." ] }
    gestures { [ "Gesto uno.", "Gesto dos." ] }
    exercises { [ "Ejercicio uno.", "Ejercicio dos." ] }
    reflection_questions { [ "¿Pregunta uno?", "¿Pregunta dos?" ] }
    active { true }
  end
end
