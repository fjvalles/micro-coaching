---
name: rails-conventions
description: Project-specific Rails 7.2 conventions for Piloto Automático. Use when writing models, controllers, services, jobs, or any Ruby code in this repo. Covers UUID PKs, discard soft-delete scopes, asdf toolchain, service object boundaries, and AI/WhatsApp domain patterns.
---

# Rails Conventions — Piloto Automático

## Toolchain (non-negotiable)

- **Always** `asdf exec bundle exec <cmd>`. Bare `bin/rails` / `bundle exec` picks wrong Ruby.
- Ruby 4.0.2, Rails 7.2, Postgres 16, Redis 7.
- Sidekiq + sidekiq-cron for background work.

## Models

- All tables use UUID PKs (`pgcrypto`). New migrations: `create_table :foo, id: :uuid`.
- `Participant` and `Conversation` use `discard` gem — **always** scope queries with `.kept`. Never `.all`.
- Phones stored as E.164 strings (`+521234567890`). Validate format on input boundary.
- JSONB columns default to `{}` not `nil` (prevents `nil.dig` in generators).
- Settings via key/value `Setting` model — read with `Setting.get("key")`.

## Controllers

- Webhook controllers: verify Meta signature via `Whatsapp::SignatureVerifier` before any work.
- Enqueue jobs, don't do work in request cycle.
- Devise-protected admin at `/admin` (custom native panel), `/sidekiq` mounted behind `admin_user`.

## Service objects (`app/services/`)

Organized by domain namespace: `Whatsapp::`, `Openai::`, `Participants::`.

Contract:
- One public method: `#call`.
- Returns a value object/struct, never raises for expected outcomes.
- AI services return struct with `body`, `prompt_used`, `tokens_input`, `tokens_output`, `model`.
- Pass collaborators via `initialize`; no global state lookups inside `#call`.

See `service-object` skill to scaffold a new one.

## Jobs (`app/jobs/`)

- Inherit `ApplicationJob`. Sidekiq adapter.
- **Idempotent**: check `Conversation.where(moment: ..., day_number: ...).exists?` before sending.
- Cron fan-out pattern: `XxxJob` (filters participants) → `XxxForParticipantJob` (does work for one).
- Cron config in `config/schedule.yml`.

See `background-job` skill for templates.

## AI calls

- Model `gpt-4.1-mini`. `temperature: 0.75` for generative, `0.3` for JSON.
- Prepend `Openai::ProgramManifesto` constant to every system prompt (≥1024 tokens enables OpenAI prompt cache, ~5min TTL).
- JSON responses: `response_format: { type: "json_object" }` + rescue `JSON::ParserError` with raw-text fallback.
- Support `dry_run: true` arg for prompt preview without API call.

## Forbidden

- `Timecop` — use `travel_to` (Rails built-in).
- `httparty`/`faraday` for one-shot calls — `Net::HTTP` is fine.
- Touching `Participant`/`Conversation` without `.kept`.
- New gems without checking `docs/decisions.md` rationale.

## Read first

- `AGENTS.md` — domain model, env vars, architecture diagram.
- `docs/decisions.md` — every non-obvious choice already made.
