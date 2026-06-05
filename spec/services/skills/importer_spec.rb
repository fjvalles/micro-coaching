require "rails_helper"

RSpec.describe Skills::Importer do
  let(:dir) { Rails.root.join("tmp/skills_source_spec") }

  before do
    FileUtils.mkdir_p(dir)
    File.write(dir.join("03_escucha_activa.txt"), skill_text("ESCUCHA ACTIVA"))
    File.write(dir.join("04_coraje.txt"), skill_text("CORAJE"))
    # Duplicate slug, higher number — should be skipped.
    File.write(dir.join("08_escucha_activa.txt"), skill_text("ESCUCHA ACTIVA"))
  end

  after { FileUtils.rm_rf(dir) }

  def skill_text(title)
    <<~TXT
      #{title}

      Definición
      Una definición de prueba.

      Señales de que te falta algo
      - Señal de prueba.

      Prácticas que ayudan a desarrollarla
      1. Práctica de prueba.

      Gestos cotidianos
      - Gesto de prueba.

      Trampa frecuente
      Una trampa.

      Ejercicios para desarrollar la habilidad

      Ejercicio 1 — Uno
      Cuerpo del ejercicio.

      Preguntas de reflexión
      1. ¿Una pregunta?

      Resumen en una frase
      Una frase.
    TXT
  end

  it "imports each file once, deriving slug from filename and skipping duplicate slugs" do
    result = described_class.new(dir: dir).call

    expect(result.created).to eq(2)
    expect(result.skipped).to eq(1)
    expect(Skill.pluck(:slug)).to contain_exactly("escucha_activa", "coraje")
    expect(Skill.find_by(slug: "escucha_activa").position).to eq(3)
  end

  it "is idempotent — re-running upserts instead of duplicating" do
    described_class.new(dir: dir).call
    result = described_class.new(dir: dir).call

    expect(result.created).to eq(0)
    expect(result.updated).to eq(2)
    expect(Skill.count).to eq(2)
  end
end
