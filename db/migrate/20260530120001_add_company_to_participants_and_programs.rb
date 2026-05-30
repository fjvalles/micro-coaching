class AddCompanyToParticipantsAndPrograms < ActiveRecord::Migration[7.2]
  # programs.company_id NULL  => general program (available to everyone)
  # programs.company_id SET   => company-only program
  def up
    add_reference :participants, :company, type: :uuid, null: true, foreign_key: true, index: true
    add_reference :programs, :company, type: :uuid, null: true, foreign_key: true, index: true

    backfill_companies_from_legacy_string
  end

  def down
    remove_reference :programs, :company, foreign_key: true
    remove_reference :participants, :company, foreign_key: true
  end

  private

  # One Company per distinct non-blank participants.company string. The legacy
  # `company` string column is kept (deprecated) so this is reversible and non-destructive.
  def backfill_companies_from_legacy_string
    names = select_values(
      "SELECT DISTINCT company FROM participants WHERE company IS NOT NULL AND btrim(company) <> ''"
    )

    names.each do |name|
      slug = unique_slug(name.parameterize.presence || "empresa")
      execute(<<~SQL.squish)
        INSERT INTO companies (id, name, slug, active, covers_membership, created_at, updated_at)
        VALUES (gen_random_uuid(), #{quote(name)}, #{quote(slug)}, true, true, now(), now())
      SQL
      execute(<<~SQL.squish)
        UPDATE participants SET company_id = (SELECT id FROM companies WHERE slug = #{quote(slug)})
        WHERE company = #{quote(name)}
      SQL
    end
  end

  def unique_slug(base)
    slug = base
    i = 1
    while select_value("SELECT 1 FROM companies WHERE slug = #{quote(slug)}")
      i += 1
      slug = "#{base}-#{i}"
    end
    slug
  end
end
