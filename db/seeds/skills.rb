# Imports the human micro-coaching skill catalog from db/seeds/skills_source/*.txt.
# Idempotent (upsert by slug). Safe to re-run after editing the source files.
result = Skills::Importer.new.call
puts "[seeds] skills — creadas: #{result.created}, actualizadas: #{result.updated}, " \
     "duplicadas omitidas: #{result.skipped} (total catálogo: #{Skill.count})"
