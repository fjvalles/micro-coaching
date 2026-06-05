module Skills
  # Parses one micro-coaching skill .txt into a structured hash. The source files
  # follow a fixed skeleton (see db/seeds/skills_source/*.txt); section headers are
  # matched by prefix because some carry the skill name as a suffix
  # (e.g. "Señales de que te falta liderazgo inspirador").
  module TextParser
    module_function

    # Ordered so each header closes the previous section. Keys map to result fields.
    # Prefix-matched: some headers carry the skill name or a verb variant as a
    # suffix (e.g. "Señales de estrés crónico", "Prácticas que ayudan a cuidarla",
    # "Ejercicios para cuidar la energía del equipo").
    HEADERS = [
      [ :definition,  /\ADefinición\z/ ],
      [ :importance,  /\APor qué importa/ ],
      [ :signals,     /\ASeñales\b/ ],
      [ :practices,   /\APrácticas\b/ ],
      [ :gestures,    /\AGestos cotidianos\z/ ],
      [ :trap,        /\ATrampa frecuente\z/ ],
      [ :exercises,   /\AEjercicios\b/ ],
      [ :reflection,  /\APreguntas de reflexión\z/ ],
      [ :one_liner,   /\AResumen en una frase\z/ ]
    ].freeze

    TEXT_SECTIONS = %i[definition importance trap one_liner].freeze
    ITEM_START    = /\A(?:-\s+|\d+\.\s+|Ejercicio\b)/i

    def parse(raw)
      lines = raw.to_s.gsub("\r\n", "\n").split("\n")
      title = lines.find { |l| l.strip.present? }.to_s.strip

      sections = split_sections(lines)

      {
        name:                 humanize(title),
        definition:           join_text(sections[:definition]),
        importance:           join_text(sections[:importance]),
        trap:                 join_text(sections[:trap]),
        one_liner:            join_text(sections[:one_liner]),
        signals:              list_items(sections[:signals]),
        practices:            list_items(sections[:practices]),
        gestures:             list_items(sections[:gestures]),
        exercises:            list_items(sections[:exercises]),
        reflection_questions: list_items(sections[:reflection])
      }
    end

    def split_sections(lines)
      sections = Hash.new { |h, k| h[k] = [] }
      current = nil

      lines.each_with_index do |line, idx|
        next if idx.zero? # title line

        header = header_for(line)
        if header
          current = header
          next
        end
        sections[current] << line if current
      end

      sections
    end

    def header_for(line)
      return nil if line.start_with?(" ", "\t") # body lines may be indented
      stripped = line.strip
      return nil if stripped.empty?

      HEADERS.find { |(_key, re)| stripped.match?(re) }&.first
    end

    def join_text(lines)
      Array(lines).map(&:strip).reject(&:empty?).join(" ").gsub(/\s+/, " ").strip
    end

    # Splits a section into items. A new item begins at a bullet ("- "), a number
    # ("1. "), or an "Ejercicio N — " heading; non-marker lines continue the
    # current item (handles wrapped source text).
    def list_items(lines)
      items = []
      current = nil

      Array(lines).each do |line|
        stripped = line.strip
        if stripped.match?(ITEM_START)
          items << current if current
          current = stripped
        elsif current && !stripped.empty?
          current = "#{current} #{stripped}"
        end
      end
      items << current if current

      items.map { |i| clean_item(i) }.reject(&:blank?)
    end

    def clean_item(item)
      item.sub(/\A-\s+/, "")
          .sub(/\A\d+\.\s+/, "")
          .sub(/\AEjercicio\s+\d+\s*[—–-]\s*/i, "")
          .gsub(/\s+/, " ")
          .strip
    end

    def humanize(title)
      title.to_s.strip.downcase.then { |t| t.empty? ? t : t[0].upcase + t[1..] }
    end
  end
end
