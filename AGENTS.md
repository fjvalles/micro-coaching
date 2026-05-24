# Piloto Automático — AGENTS.md

Rails 7.2 micro-coaching app. Delivers a 14-day behavioral-change program via WhatsApp. Orchestrates OpenAI-generated messages through Sidekiq jobs triggered by Meta Cloud API webhooks.

## Source-of-truth docs

- **Business rules** → [`docs/business-rules.md`](docs/business-rules.md) (canonical; read first for any "how does X work?" question)
- **Past decisions** → [`docs/decisions.md`](docs/decisions.md) (why we chose what we chose)
- **Architecture + setup** → this file
- **Commercial strategy** → `docs/commercial-strategy.md`, `docs/lean-canvas.md`, `docs/dvf-analysis.md`, `docs/customer-interviews.md`, `docs/offer-hormozi.md`, `docs/brand-positioning.md`
- **Read in admin UI** → `/admin/docs` (renders the markdown files above; controller: `app/controllers/admin/docs_controller.rb`; whitelist-based — add new docs to `DOCS` constant)
- **Verify `path:line` refs** → `bin/check-doc-refs` (run after refactor; CI-ready)

## Running the app

Always use asdf — bare `bin/rails` / `bundle exec` will use wrong Ruby.

```bash
# Dev server (Rails + JS/CSS bundlers + Sidekiq)
asdf exec bundle exec foreman start -f Procfile.dev

# Rails console
asdf exec bundle exec rails console

# Migrations
asdf exec bundle exec rails db:migrate

# Tests
asdf exec bundle exec rspec
```

Services required locally (Homebrew):
- PostgreSQL 16: `brew services start postgresql@16`
- Redis 7: `brew services start redis`

## Architecture

```
WhatsApp webhook → WebhooksController → ProcessIncomingMessageJob
                                             ↓
                                    Participants::MessageClassifier
                                    (initial_pattern | checkin_response | free_user)
                                             ↓
                            Openai::CheckinSummarizer / FreeResponseGenerator
                                             ↓
                                    Whatsapp::Client → Meta API
```

Cron jobs (sidekiq-cron, `config/schedule.yml`):
- `MorningWakeJob` — hourly, fans out to `MorningWakeForParticipantJob` for participants whose local hour == `Setting.get("wake_hour")`
- `CheckinEveningJob` — hourly, same pattern at 20:00 local
- `AdvanceDayJob` — daily at 06:00 UTC, calls `Participants::DayAdvancer`

## Domain model

| Model | Key fields |
|-------|-----------|
| `Program` | `slug`, `total_days`, `manifesto`, `active` |
| `DayContent` | `program_id`, `day_number`, `phase` (see/choose/anchor), `morning_template`, `iareto_text`, `checkin_questions`, `ai_system_prompt` |
| `Participant` | `phone_e164`, `status` (pending/active/completed/paused), `current_day`, `timezone`, `initial_pattern`, `energy_map` (jsonb), `pending_checkin_at` |
| `Conversation` | `moment` (welcome/morning_wake/iareto/checkin_question/checkin_response/free_user/free_assistant/manifesto), `role` (user/assistant/system), `day_number`, delivery timestamps |
| `DailyReport` | `ai_summary`, `ai_key_pattern` (OpenAI output), `raw_text` |
| `Setting` | key/value store — `wake_hour`, etc. |

All tables use UUID PKs (`pgcrypto`). `Participant` and `Conversation` use `discard` gem for soft deletes — always scope with `.kept`.

## Service objects

- `app/services/whatsapp/Client` — `send_text`, `send_template`, `mark_as_read` via `Net::HTTP` with exponential-backoff retry (3 attempts, retries on 429/5xx)
- `app/services/whatsapp/InboundParser` — parses Meta webhook payload into messages + statuses
- `app/services/whatsapp/SignatureVerifier` — `secure_compare` on `X-Hub-Signature-256`
- `app/services/whatsapp/TemplateSender` — wraps `Client#send_template` with template name helpers
- `app/services/openai/MorningMessageGenerator` — builds personalized wake message; supports `dry_run: true`
- `app/services/openai/FreeResponseGenerator` — free-form AI reply; uses conversation history
- `app/services/openai/CheckinSummarizer` — returns `{summary, key_pattern}` as JSON; `temperature: 0.3`
- `app/services/openai/ManifestoGenerator` — day-15 closing manifesto
- `app/services/openai/ProgramManifesto` — shared constant prepended to all system prompts (promotes OpenAI prompt caching ≥1024 tokens)
- `app/services/participants/MessageClassifier` — classifies inbound message as `initial_pattern_answer | checkin_response | free_user`
- `app/services/participants/DayAdvancer` — advances `current_day`, sets `started_at` / `completed_at`
- `app/services/participants/Enroller` — sets `status: :active`, stamps `enrolled_at`

## Panel de Administración (Nativo)

- Panel a medida montado en `/admin`, protegido por Devise `AdminUser`.
- Dashboard moderno con métricas clave y actividad reciente de participantes y mensajes.
- Acciones nativas en UI para "Inscribir Participante", "Archivar" (soft-delete vía `discard`), y desarchivar.
- Sidekiq Web en `/sidekiq` protegido bajo autenticación de `admin_user`.

## Environment variables

Copy `.env.example` → `.env`. Required:

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | OpenAI API |
| `META_PHONE_NUMBER_ID` | Meta Cloud API phone number |
| `META_BUSINESS_ACCOUNT_ID` | Meta business account |
| `META_ACCESS_TOKEN` | Meta permanent token |
| `META_APP_SECRET` | Webhook signature verification |
| `META_WEBHOOK_VERIFY_TOKEN` | Webhook challenge handshake |
| `META_API_VERSION` | Default `v21.0` |
| `PROGRAM_LOCALE` | WhatsApp template locale, default `es_MX` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Seeded admin credentials |

## Tests

RSpec + FactoryBot + VCR + WebMock. WebMock blocks all external HTTP (allows localhost).

```bash
asdf exec bundle exec rspec                  # all
asdf exec bundle exec rspec spec/models/     # models only
asdf exec bundle exec rspec spec/jobs/       # jobs only
```

OpenAI service objects stubbed with `allow_any_instance_of(...).to receive(:call)` — no cassettes needed in CI. To record real traffic: `VCR.use_cassette("name") { ... }`.

Use `travel_to` (Rails built-in), not Timecop.

## Conventions

- Soft deletes via `discard` — always `.kept` scope on `Participant` and `Conversation`
- Job idempotency: check `Conversation.where(moment: ..., day_number: ...)` before sending
- Phone numbers stored as E.164 (`+56912345678`)
- All AI calls return a struct with `body`, `prompt_used`, `tokens_input`, `tokens_output`, `model`
- Model: `gpt-4.1-mini`, `temperature: 0.75` (generative), `0.3` (JSON summarizer)
- CheckinSummarizer uses `response_format: { type: "json_object" }` with fallback if parse fails
- Program-scoped content: `DayContent` belongs to `Program`; `Participant` belongs to `Program`

## Quality gate (mandatory on code change)

Before declaring a code task done, run this chain. Skip steps only when clearly N/A and say so.

1. **`rails-conventions`** skill — verify UUID PK, `.kept` scope on Participant/Conversation, asdf usage, service boundaries.
2. **Domain skill** if touched: `service-object`, `db-migration`, `background-job`, `openai-service`, `whatsapp-integration`, `admin-redesign`.
3. **Reuse check** — grep for existing helpers/services/concerns before introducing new code. Prefer extending over duplicating.
4. **`testing`** skill — add/extend RSpec specs (model/service/job/request). Stub OpenAI per project pattern; never let WebMock hit real APIs.
5. **Run rubocop**: `asdf exec bundle exec rubocop -A <touched files>` (PostToolUse hook also reports inline).
6. **Run rspec**: `asdf exec bundle exec rspec <touched specs>`. Bullet raises in test on N+1 — fix, don't silence.
7. **Boot + manual verify** for UI/feature changes via `verify` skill; inspect `log/bullet.log` in dev.
8. **`code-review`** skill — self-audit diff against project-specific checks (soft-delete scopes, job idempotency, prompt caching, signature verification).
9. **`documentation`** skill — if non-obvious decision: update `docs/decisions.md`, `docs/business-rules.md`, or AGENTS.md. New env var → `.env.example` + table above.
10. **`commits`** skill — Conventional Commit with project scope. No co-author trailers.

The `Stop` hook runs rubocop + rspec on session-edited Ruby files; treat its output as the floor, not the ceiling.

## Known gaps (conscious, see docs/decisions.md)

- WhatsApp template auto-submission is manual via Meta dashboard
- No voice transcription (media_id is rejected with a text prompt)
- No deployment config (Kamal/Heroku/Render not set up)
- Dry-run prompt preview UI not wired (service supports it: `MorningMessageGenerator.new(...).call(dry_run: true)`)
