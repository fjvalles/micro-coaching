require "rails_helper"

RSpec.describe Skills::TextParser do
  let(:raw) do
    <<~TXT
      ESCUCHA ACTIVA

      Definición
      La escucha activa es la disciplina de poner atención plena a lo que el
      otro dice antes de responder.

      Por qué importa en el trabajo
      Sin esta habilidad, las conversaciones se vuelven monólogos paralelos.

      Señales de que te falta escucha activa
      - "Ya sé lo que va a decir" aparece antes de que terminen.
      - Interrumpes con frecuencia.

      Prácticas que ayudan a desarrollarla
      1. Suspender el juicio: entender primero, evaluar después.
      2. Parafrasear: "lo que entiendo es..." abre espacio a la corrección.

      Gestos cotidianos
      - Dejar que el otro termine sin interrumpir.

      Trampa frecuente
      Confundir estar disponible con estar presente.

      Ejercicios para desarrollar escucha activa

      Ejercicio 1 — Tres minutos sin interrumpir
      En tu próxima conversación importante, no interrumpas en los primeros
      tres minutos.

      Ejercicio 2 — La paráfrasis
      Cierra tu próxima conversación con: "lo que entendí es...".

      Preguntas de reflexión
      1. ¿A quién escuchaste sin estar presente esta semana?
      2. ¿Escuchaste para entender o para responder?

      Resumen en una frase
      Escuchar activamente no es callar: es estar presente.
    TXT
  end

  subject(:parsed) { described_class.parse(raw) }

  it "humanizes the title into a name" do
    expect(parsed[:name]).to eq("Escucha activa")
  end

  it "joins wrapped text sections into single paragraphs" do
    expect(parsed[:definition]).to eq(
      "La escucha activa es la disciplina de poner atención plena a lo que el otro dice antes de responder."
    )
    expect(parsed[:one_liner]).to eq("Escuchar activamente no es callar: es estar presente.")
  end

  it "extracts bullet sections as arrays, stripping markers" do
    expect(parsed[:signals]).to eq([
      '"Ya sé lo que va a decir" aparece antes de que terminen.',
      "Interrumpes con frecuencia."
    ])
    expect(parsed[:gestures]).to eq([ "Dejar que el otro termine sin interrumpir." ])
  end

  it "extracts numbered sections as arrays" do
    expect(parsed[:practices].size).to eq(2)
    expect(parsed[:practices].first).to start_with("Suspender el juicio")
    expect(parsed[:reflection_questions].size).to eq(2)
  end

  it "extracts exercises joining heading and body, stripping the Ejercicio prefix" do
    expect(parsed[:exercises].size).to eq(2)
    expect(parsed[:exercises].first).to start_with("Tres minutos sin interrumpir En tu próxima")
  end

  it "handles header wording variants (señales/prácticas/ejercicios suffixes)" do
    variant = raw.sub("Señales de que te falta escucha activa", "Señales de estrés crónico")
                 .sub("Prácticas que ayudan a desarrollarla", "Prácticas que ayudan a cuidarla")
                 .sub("Ejercicios para desarrollar escucha activa", "Ejercicios para cuidar la energía")
    result = described_class.parse(variant)
    expect(result[:signals]).not_to be_empty
    expect(result[:practices]).not_to be_empty
    expect(result[:exercises]).not_to be_empty
  end
end
