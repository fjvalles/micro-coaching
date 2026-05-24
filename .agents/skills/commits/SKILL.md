---
name: commits
description: Write commit messages for Piloto Automático following Conventional Commits with project-specific scopes. Use when creating a commit, splitting a branch into commits, or writing a PR title.
---

# Commits

## Format

```
<type>(<scope>): <subject>

<body — only when "why" isn't obvious from diff>
```

Subject: ≤50 chars, imperative, lowercase, no period. Body wraps at 72.

## Types

- `feat` — user-visible behavior change
- `fix` — bug fix
- `refactor` — internal, no behavior change
- `perf` — measurable performance change (e.g., prompt cache hit rate)
- `test` — tests only
- `docs` — README, AGENTS.md, docs/decisions.md, inline
- `chore` — deps, build, tooling
- `db` — migration / schema

## Scopes (project)

- `whatsapp` — Meta API, templates, webhooks, signature
- `openai` — AI services, prompts, manifesto
- `jobs` — Sidekiq, cron, fan-out
- `participants` — enrollment, day advance, classifier
- `admin` — native panel, Devise
- `models` — AR models, validations, scopes
- `infra` — Procfile, env, asdf, brew services

## Examples

```
feat(openai): cache program manifesto in system prompt

Prepend Openai::ProgramManifesto::TEXT to every AI call so the shared
~1.2k-token block hits OpenAI's prompt cache. Expected 5–10× cost
reduction on morning broadcasts.
```

```
fix(jobs): make MorningWakeForParticipantJob idempotent

Sidekiq retry was duplicating morning messages. Check for existing
Conversation(moment: :morning_wake, day_number: current_day) before send.
```

```
db: add pending_checkin_at to participants
```

```
refactor(participants): extract MessageClassifier from job
```

## When to add body

- The "why" isn't visible in the diff (incident reference, perf number, decision).
- Trade-off chosen vs. alternative.
- Migration with manual ops needed.

Otherwise: subject only. The diff explains the "what".

## When to split

- One commit = one logical change.
- Migration + model + service touching the same feature can live in one commit if reversible together.
- Refactor + behavior change → split.

## Don't

- No "wip", "fixes", "updates", "various" subjects.
- **Never** add `Co-Authored-By:` trailers. No `Co-Authored-By: Codex`, no `Co-Authored-By: <anyone>`. Single author = the human running the commit. Hard rule, no exceptions, no "unless pairing".
- No `Generated with Codex` / `🤖` / tool attribution footers.
- No emoji.
- No referencing PR numbers (PR description does that).
