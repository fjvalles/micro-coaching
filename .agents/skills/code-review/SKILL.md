---
name: code-review
description: Review a diff or PR against Piloto Automático standards. Project-specific checks beyond generic Rails review — soft-delete scopes, job idempotency, prompt caching, signature verification, asdf toolchain, docs/decisions.md drift. Use when reviewing a PR, auditing a branch before merge, or pre-flighting your own diff.
---

# Code Review — Piloto Automático

Run through these in order. One line per finding: `path:line — issue. fix.`

## Hard blockers

- [ ] `Participant` / `Conversation` query without `.kept` scope.
- [ ] Webhook handler missing `Whatsapp::SignatureVerifier` call.
- [ ] WhatsApp send without idempotency check (`Conversation.where(moment:, day_number:).exists?`).
- [ ] AI service missing `Openai::ProgramManifesto::TEXT` prepend (kills prompt cache, 5–10× cost).
- [ ] Hardcoded phone, token, or API key.
- [ ] `rescue StandardError` (or bare `rescue`) swallowing Sidekiq retry.
- [ ] AR instance passed as job arg (use ID).
- [ ] New migration without UUID PK (`id: :uuid`).
- [ ] Timecop introduced (must be `travel_to`).
- [ ] New admin controller missing inheritance from `Admin::BaseController`.
- [ ] Admin page elements bypassing design tokens or layouts from `admin.css`.
- [ ] Commit includes `Co-Authored-By:` trailer or `🤖 Generated with Codex` footer. Strip before merge.

## Architecture smells

- [ ] Business logic in controller or job — extract to service.
- [ ] Service with multiple public methods (only `#call`).
- [ ] AI service missing `dry_run:` keyword.
- [ ] JSON-mode AI call without `JSON::ParserError` fallback.
- [ ] Cron-driven work scheduled via `wait:` instead of `schedule.yml`.
- [ ] Fan-out without per-participant child job.
- [ ] New gem added — is it justified vs. stdlib? (`Net::HTTP` > `httparty` for one-shots).

## Testing

- [ ] Feature touches model + service + job but spec only in one dir.
- [ ] New job missing idempotency spec (run twice → one effect).
- [ ] New AI service missing dry-run spec.
- [ ] New webhook handler missing signature-mismatch spec.
- [ ] WebMock not stubbing new external call (will fail CI).

## Schema

- [ ] New JSONB column without `default: {}`.
- [ ] New string column that should be enum.
- [ ] Index missing on FK or query column.
- [ ] Phone column not E.164 validated.

## Docs

- [ ] Non-obvious decision not added to `docs/decisions.md`.
- [ ] New env var not in `.env.example` and `AGENTS.md` table.
- [ ] Architecture change not reflected in `AGENTS.md` diagram.
- [ ] New service not mentioned in `AGENTS.md` service-objects table.

## Output format

```
app/jobs/foo_job.rb:23 — passes Participant instance to perform_later. Use participant.id.
app/services/openai/bar.rb:11 — no ProgramManifesto prepend. Prepend Openai::ProgramManifesto::TEXT.
spec/jobs/foo_job_spec.rb — missing idempotency case. Run perform twice, assert single Conversation.
```

No praise, no scope creep, no formatting nits.
