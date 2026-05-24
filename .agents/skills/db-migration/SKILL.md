---
name: db-migration
description: Write or review a database migration in Piloto Automático. Covers UUID PKs, JSONB defaults, soft-delete columns, indexes, reversibility, and zero-downtime concerns. Use when adding/altering a table or column.
---

# DB Migration

## Generate

```bash
asdf exec bundle exec rails g migration AddFooToBars foo:string
```

Edit the generated file — defaults are often wrong for this project.

## Rules

### UUID PKs everywhere

```ruby
create_table :foos, id: :uuid do |t|
  t.references :participant, type: :uuid, foreign_key: true, null: false
  t.timestamps
end
```

`pgcrypto` already enabled. Don't `enable_extension` again.

### JSONB columns

Default to `{}` not `nil`:

```ruby
t.jsonb :energy_map, null: false, default: {}
```

Prevents `nil.dig` in AI generators.

### Soft delete

If the model uses `discard`:

```ruby
t.datetime :discarded_at
add_index :foos, :discarded_at
```

### Indexes

- FK columns: always indexed (Rails `t.references` does this).
- Query columns: index anything in a `where` you call frequently.
- Composite for compound queries: `add_index :conversations, [:participant_id, :moment, :day_number]`.

### Enums

Use string columns + Rails `enum`, not Postgres enums (Rails migrations don't handle PG enums cleanly):

```ruby
t.string :status, null: false, default: "pending"
add_index :foos, :status
```

In model:
```ruby
enum :status, { pending: "pending", active: "active", completed: "completed" }
```

### Phones

```ruby
t.string :phone_e164, null: false
add_index :foos, :phone_e164, unique: true
```

Validate format in model.

## Reversibility

Use `change` when reversible. Use `up`/`down` when not (data backfill, dropping a column with data).

Backfills: never inline in the schema-change migration — split into a separate data migration (or one-shot Rake task) so schema migrations stay fast and rollback-safe.

## Zero-downtime concerns

Production is small now but plan ahead:
- Adding a NOT NULL column with no default on a populated table → 2-step: add nullable + backfill + set NOT NULL.
- Renaming column → 3-step: add new + dual-write + drop old.
- Removing column → ignore in model first, deploy, then drop.

For current scale these don't bite — but call it out in PR description if the table grows.

## After migrating

```bash
asdf exec bundle exec rails db:migrate
asdf exec bundle exec rails db:rollback  # always verify reversibility
asdf exec bundle exec rails db:migrate
```

`db/schema.rb` is the committed source of truth. Don't hand-edit.

## Checklist

- [ ] `id: :uuid`?
- [ ] FK has `type: :uuid`?
- [ ] JSONB has `default: {}`?
- [ ] Index on FK + frequent query columns?
- [ ] Reversible, or has explicit `down`?
- [ ] `db/schema.rb` regenerated and committed?
- [ ] Model updated (validations, enum, scope)?
- [ ] Spec added for new validations / scopes?
