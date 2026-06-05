module Skills
  # Imports the micro-coaching skill catalog from db/seeds/skills_source/*.txt into
  # the Skill table. Idempotent: upserts by slug (slug derived from the file name,
  # minus the numeric prefix). On slug collision (e.g. two paciencia_intelectual
  # variants) the lowest-numbered file wins; later ones are skipped.
  class Importer
    DEFAULT_DIR = Rails.root.join("db/seeds/skills_source").freeze
    Result = Struct.new(:created, :updated, :skipped, keyword_init: true)

    def initialize(dir: DEFAULT_DIR, parser: Skills::TextParser)
      @dir = Pathname.new(dir)
      @parser = parser
    end

    def call
      created = updated = skipped = 0
      seen = {}

      files.each do |path|
        position = file_position(path)
        slug = file_slug(path)

        if seen.key?(slug)
          skipped += 1
          Rails.logger.info("[Skills::Importer] skipped duplicate slug #{slug} (#{path.basename})")
          next
        end
        seen[slug] = true

        attrs = @parser.parse(path.read).merge(slug: slug, position: position, active: true)
        skill = Skill.find_or_initialize_by(slug: slug)
        was_new = skill.new_record?
        skill.assign_attributes(attrs)
        skill.save!
        was_new ? created += 1 : updated += 1
      end

      Result.new(created: created, updated: updated, skipped: skipped)
    end

    private

    def files
      Dir.glob(@dir.join("*.txt")).sort.map { |f| Pathname.new(f) }
    end

    def file_position(path)
      path.basename.to_s[/\A(\d+)/, 1]&.to_i
    end

    def file_slug(path)
      path.basename(".txt").to_s.sub(/\A\d+_/, "")
    end
  end
end
