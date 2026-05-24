# Seeds every entry in Setting::SCHEMA that is not yet persisted. The schema
# is the source of truth for keys, types, categories, descriptions, defaults.
Setting.seed_defaults!

# Backfill rows that pre-date the schema rewrite: refresh value_type, category
# and description for any row whose key is in SCHEMA. Leaves the value alone.
Setting::SCHEMA.each do |key, spec|
  record = Setting.find_by(key: key)
  next unless record
  record.update_columns(
    value_type:  spec[:type].to_s,
    category:    spec[:category],
    description: spec[:description]
  )
end
