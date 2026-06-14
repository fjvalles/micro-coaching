# Impulso — AGENTS.md

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
                            Participants::InboundIntentClassifier
                            (checkin_answer | program_question | support_request |
                             restricted_information_request | off_topic |
                             risk_or_sensitive | stop_or_pause | unclear)
                                             ↓
                            Openai::CheckinSummarizer / FreeResponseGenerator
                                             ↓
                                    Whatsapp::Client → Meta API
```

Cron jobs (sidekiq-cron, `config/schedule.yml`):
- `MorningWakeJob` — hourly, fans out to `MorningWakeForParticipantJob` for participants whose local hour == `Setting.get("wake_hour")`
- `CheckinEveningJob` — hourly, same pattern at 20:00 local
- `AdvanceDayJob` — daily at 06:00 UTC, calls `Participants::DayAdvancer`
- `RefreshMethodologyInsightsJob` — daily at 03:30 UTC, materializes methodology insights for the admin dashboard
- `DailyBackupJob` — daily at 03:00 UTC, runs `pg_dump` and uploads the encrypted custom database backup to Google Drive
- `PauseInactiveParticipantsJob` — daily at 05:00 UTC, pauses `active` participants with no inbound in `inactivity_pause_days`
- `SubscriptionBillingJob` — daily at 08:00 UTC, charges due Webpay Oneclick subscriptions; dunning to `past_due` after `subscription_max_retries`
- `CapacityAlertJob` — every 15 min, warns Sentry past `capacity_queue_latency_alert_seconds` / `capacity_backlog_alert_threshold` (0 = off)
- `AutoPromptTuningJob` — weekly Monday 04:00 UTC; scores free-chat quality and, when enabled, proposes/applies bounded `free_chat_style_guardrails` edits with rollback
- `RevalidateResourcesJob` — daily at 04:15 UTC, re-checks stale approved resources and archives dead links

## Domain model

| Model | Key fields |
|-------|-----------|
| `Company` | `name`, `slug`, `coach_name` (override), `covers_membership`, `active`; soft-deleted (`discard`). `has_many :participants, :programs` |
| `Program` | `slug`, `total_days`, `manifesto`, `active`, `response_mode`, `company_id` (nil = general), `next_program_id` (self-ref FK; cadena multi-ciclo Nivel 1→2). `has_many :enrollments` |
| `DayContent` | `program_id`, `day_number`, `phase` (see/choose/anchor), `morning_template`, `iareto_text`, `checkin_questions`, `ai_system_prompt` |
| `Participant` | `phone_e164`, `status` (pending/active/completed/paused/awaiting_payment), `current_day`, `timezone`, `initial_pattern`, `energy_map` (jsonb), `pending_checkin_at`, `company_id` (assoc shadows legacy `company` string), `role`, `response_mode`, `coach_notes` (admin-only, **nunca** a la IA), `focus_hint` (directriz abstracta, sí a la IA), `ai_summary` (memoria rodante IA, post-checkin). `payment_required?` gates individual enroll. `has_many :enrollments` |
| `Payment` | Webpay Plus/Oneclick: `amount` (CLP, IVA-incl), `status` (pending/authorized/rejected/failed/aborted/refunded), `buy_order`, `token`, `commission_amount`, `net_amount`; `belongs_to :participant/:company/:program/:subscription` |
| `Subscription` | Webpay Oneclick recurring: `status` (pending/active/past_due/canceled/paused), `amount_clp`, `plan`, `tbk_user`/`tbk_username` (recurring token), `billing_interval_days`, `next_billing_at`, `billing_cycle_count`, `failed_attempts`; soft-deleted (`discard`); `has_many :payments`. ⚠️ scope with `.kept` |
| `Conversation` | `moment` (welcome/morning_wake/iareto/checkin_question/checkin_response/free_user/free_assistant/manifesto), `role` (user/assistant/system), `day_number`, delivery timestamps, `media_id`, `transcription`, `voice_analysis` (jsonb) |
| `DailyReport` | `ai_summary`, `ai_key_pattern` (OpenAI output), `raw_text` |
| `Setting` | key/value store — `wake_hour`, `response_mode`, etc. |
| `PendingResponse` | `participant_id`, `conversation_id`, `status` (pending/approved/sent/rejected), `draft_body`, `delivery_kind` |
| `PromptTemplate` | `key`, `program_id`, `day_number`, `current_body`, `current_version` |
| `PromptVersion` | `prompt_template_id`, `version`, `body`, `origin` (service/day_content/admin/analysis) |
| `PromptAnalysis` | `prompt_template_id`, `findings` (jsonb), `suggested_body`, `rationale` |
| `PromptExecution` | `prompt_template_id`, `prompt_version_id`, `program_id`, `participant_id`, `conversation_id`, `rendered_messages` (jsonb), `output_body`, tokens, `billable_seconds`, latency |
| `ConversationQualityScore` | Weekly deterministic score for free-chat quality: `window_start/end`, `score`, `sample_size`, `subscores`, `examples` |
| `PromptTuningRun` | Auto-tuning audit/canary row: `status`, `mode`, score/baseline/post-score, current/proposed/previous/applied guardrails, findings, validation errors, apply/reject/rollback timestamps |
| `UnknownInbound` | `phone`, `wamid`, `message_type`, `body_preview`, `received_at` |
| `MethodologyInsight` | `scope`, `payload` (jsonb), `generated_at`, `program_id` |
| `CoachSession` | `participant_id`, `scheduled_at`, `duration_minutes`, `status` (scheduled/confirmed/completed/cancelled), `notes`, `reminder_sent_at` |
| `Skill` | Catálogo de 82 habilidades **humanas del participante** (no de la IA), importadas de `db/seeds/skills_source/*.txt`: `slug`, `name`, `position`, `definition`, `importance`, `trap`, `one_liner`, arrays jsonb `signals`/`practices`/`gestures`/`exercises`/`reflection_questions`. `has_many :skill_detections` |
| `SkillDetection` | `participant_id`, `conversation_id`, `skill_id`, `confidence`, `source` (moment), `detected_at`. Único `[conversation_id, skill_id]` |
| `Enrollment` | Ledger histórico de ciclos (modelo **secuencial**; estado vivo en `Participant`): `belongs_to :participant/:program`, `cycle_number` (global por participante), `status` (active/completed/canceled), `started_at`, `completed_at`. Único `[participant_id, program_id, cycle_number]`. Escrito por `Activator`/`DayAdvancer`/`ReEnroller` |
| `Resource` | Catálogo curado de links públicos (`kind`: video/article/audio_ref; `status`: pending/verified/approved/rejected/dead; `source`: manual/program_seed/gap_detection), `topics` jsonb, scope opcional por `program_id`, soft-deleted (`discard`). Solo `approved` + verificado recientemente es enviable |
| `ResourceDelivery` | Auditoría de qué `Resource` se anexó a qué participante/conversación/momento |
| `CopilotSession` | Hilo de chat del copiloto de operaciones (superadmin): `belongs_to :admin_user`, `status` (active/archived), `tokens_input`/`tokens_output` (presupuesto por sesión), `metadata`. `has_many :copilot_messages, :copilot_pending_actions` |
| `CopilotMessage` | Transcript append-only de una sesión (también es el log de auditoría): `role` (user/assistant/tool/system), `content`, `tool_name`, `tool_args` (jsonb), `tool_result` (jsonb), tokens. Broadcast en vivo vía Turbo |
| `CopilotPendingAction` | Gate humano: act tool propuesta por el copiloto, en espera de aprobación: `tool_name`, `args` (jsonb), `status` (pending/approved/rejected/executed/failed), `result` (jsonb), `approved_by`, `executed_at`. Ejecutada solo por `Copilot::ActExecutor` al aprobar |

All tables use UUID PKs (`pgcrypto`). `Participant` and `Conversation` use `discard` gem for soft deletes — always scope with `.kept`.

## Service objects

- `app/services/whatsapp/Client` — `send_text`, `send_template`, `mark_as_read` via `Net::HTTP` with exponential-backoff retry (3 attempts, retries on 429/5xx)
- `app/services/whatsapp/InboundParser` — parses Meta webhook payload into messages + statuses
- `app/services/whatsapp/SignatureVerifier` — `secure_compare` on `X-Hub-Signature-256`
- `app/services/whatsapp/TemplateSender` — wraps `Client#send_template` with template name helpers
- `app/services/whatsapp/DailyTemplateName` — resolves WhatsApp template name enforcing 14-day cycle unless custom overridden
- `app/services/whatsapp/AdminTemplateCatalog` — builds the admin manual-send template dropdown: welcome + per-day (despertar/iareto/checkin) derived from the participant's program DayContents with prefilled variables, plus optional extras from the `admin_message_templates` Setting
- `app/services/whatsapp/MediaFetcher` — downloads media attachment binary payloads from Meta API
- `app/services/outbound/Dispatcher` — decides "send now" vs "queue for admin" based on response mode
- `app/services/ResponseMode` — resolves response mode precedence (participant > program > global Setting)
- `app/services/openai/MorningMessageGenerator` — builds personalized wake message; supports `dry_run: true`
- `app/services/openai/FreeResponseGenerator` — free-form AI reply; uses conversation history
- `app/services/conversations/QualityScorer` — deterministic free-chat quality scorer; no tokens, returns score/subscores/examples
- `app/services/openai/GuardrailProposer` — JSON-mode internal analyzer that proposes bounded edits to `free_chat_style_guardrails`
- `app/services/guardrails/Validator` — hard gate for prompt-tuning candidates (anchors, max length, no URL/PII, bounded diff)
- `app/services/openai/CheckinSummarizer` — returns `{summary, key_pattern}` as JSON; `temperature: 0.3`
- `app/services/openai/ManifestoGenerator` — day-15 closing manifesto
- `app/services/openai/AudioTranscriber` — transcribes audio using Whisper / gpt-4o-mini-transcribe
- `app/services/openai/VoiceAnalyzer` — analyzes voice emotion/energy using gpt-4o-audio-preview
- `app/services/openai/Retryable` — concern offering exponential backoff retry logic for OpenAI API calls
- `app/services/openai/ModelRouter` — resolves per-task OpenAI models from Settings with fallback to `openai_model`
- `app/services/openai/PromptLogger` — records LLM execution metadata and payloads to `PromptExecution` / `PromptVersion`
- `app/services/openai/PromptCritic` — analyzes prompts and generates suggestions
- `app/services/openai/PatternClusterer` — clusters key participant patterns using LLM
- `app/services/openai/ProgramManifesto` — shared constant prepended to all system prompts (promotes OpenAI prompt caching ≥1024 tokens)
- `app/services/openai/ParticipantSummarizer` — rolling AI memory of the participant; re-run by `RefreshParticipantSummaryJob` after each check-in, writes `Participant#ai_summary` (abstracted, AI-safe). Gated by `participant_summary_enabled`
- `app/services/methodology/InsightBuilder` — builds 6 scopes of nightly aggregated insights
- `app/services/participants/MessageClassifier` — classifies inbound message as `program_intake | initial_pattern_answer | checkin_response | free_user`
- `app/services/openai/ProgramGenerator` — turns personalized-program intake answers into a validated JSON program **spec** (JSON mode, prompt-caching prefix, `task: :program_generator`); persistence is `Programs::Builder`'s job. Gated by `program_intake_enabled`. See `business-rules.md` §29
- `app/services/resources/Catalog` — stable prompt block of approved/sendable resources, scoped to general + participant program
- `app/services/resources/MessageBuilder` — strips hallucinated URLs from AI bodies and appends only approved catalog URLs selected by ID
- `app/services/resources/Finder` — only legitimate creator of new resource URLs; uses OpenAI web search citations and persists only cited candidates
- `app/services/resources/Verifier` — validates public URL, blocks private hosts, fetches metadata, and runs an OpenAI JSON judge before marking verified/rejected/dead
- `app/services/resources/GapDetector` — optional autodiscovery classifier for conversations; gated by `resource_autodiscovery_enabled`
- `app/services/participants/IntakeStarter` — entry point to the personalized-program flow: flips to `status: :intake`, resets `intake_state` (`awaiting_open: true`), sends the opener template (`SendIntakeOpenerJob`; cold contact can't receive free text)
- `app/services/participants/IntakeHandler` + `IntakeQuestions` — WhatsApp intake state machine; records one answer into `Participant#intake_state` (jsonb), advances the numeric `step`, returns the next question. `ProgramGenerationJob` runs on completion
- `app/services/programs/Builder` — persists a generated spec as a `Program` **template** (`template: true`, `active: false`) + `DayContent`s in a transaction (unique, format-valid slug)
- `app/services/programs/Cloner` — deep-copies a template `Program` (+`DayContent`s) into a live copy (`template: false`, `active: true`) for one participant
- `app/services/programs/Approver` — promotes a reviewed template: clone → assign → seed `initial_pattern` from intake → `Activator`. Shared by the auto path and admin approval
- `app/services/programs/OverviewMessage` — deterministic "what to expect" message (scope, duration, daily cadence, see→choose→anchor arc) built from the participant's program; sets expectations to reduce uncertainty/improve completion. Never reveals future-day challenge content. Sent by `SendProgramOverviewJob` (enqueued from `Activator`, gated on the 24h window)
- `app/services/participants/InboundIntentClassifier` — semantic JSON classifier for inbound WhatsApp text/audio transcripts; prevents non-check-in messages from consuming pending check-ins, blocks restricted data/methodology/future-content requests, and routes support/sensitive/pause intents
- `app/services/participants/DayAdvancer` — advances `current_day`, sets `started_at` / `completed_at`
- `app/services/participants/Enroller` — creates participant; activates immediately via `Activator` unless individual payment is required (`payment_required?`), in which case leaves `:awaiting_payment`
- `app/services/participants/AudioProcessor` — orchestrates audio downloading, transcription, paralinguistic analysis
- `app/services/backups/DatabaseDumper` — dumps PostgreSQL database
- `app/services/backups/GoogleDriveUploader` — uploads backups to Google Drive
- `app/services/participants/Activator` — single activation path (sets `status: :active`, `current_day: 1`, opens cycle-1 `Enrollment`, fires `SendWelcomeJob`); idempotent; shared by `Enroller`, admin enroll, and payment commit
- `app/services/participants/ProgramStarter` — admin-only immediate start path for day 0/1 participants; ensures active day 1 state/enrollment, enqueues welcome when needed, and enqueues `MorningWakeForParticipantJob` without waiting for the cron hour
- `app/services/participants/ReEnroller` — transitions a completed participant into `program.next_program` (sequential multi-cycle): repoints `program_id`/`current_day: 1`/`status: active`, opens a new `Enrollment` cycle, cancels stale active cycles, resets `ai_summary`, fires `SendWelcomeJob`. Admin button on `/admin/participants/:id`. See `business-rules.md` §26
- `app/services/finances/CostCalculator` — single source of truth for USD operating costs over a range (OpenAI usage priced from `PromptExecution` + prorated manual fixed costs); shared by `Admin::FinancesController` and `Admin::ProfitLossController`
- `app/services/ops/CapacitySnapshot` — read-only Sidekiq/DB-pool/Redis capacity snapshot (graceful if Redis down); shared by `Admin::HealthController` and `CapacityAlertJob`
- `app/services/webpay/Client` — Transbank Webpay Plus wrapper (`create`/`commit`) for one-time payments; honors `webpay_enabled` + `webpay_environment`
- `app/services/webpay/OneclickClient` — Transbank Webpay Oneclick (Mall) wrapper: inscription (`start`/`finish`) + recurring `charge`; honors `webpay_oneclick_enabled` kill-switch
- `app/services/skills/Importer` — parses `db/seeds/skills_source/*.txt` into the `Skill` catalog; idempotent upsert by slug (dedupe first-wins)
- `app/services/skills/TextParser` — parses one skill `.txt` into structured sections; header matching by prefix
- `app/services/skills/CoachingHint` — builds a coaching nudge for the participant's dominant skill (30d); injected into `FreeResponseGenerator` + `MorningMessageGenerator`
- `app/services/openai/SkillTagger` — classifies an inbound message against the skill catalog (JSON mode); returns 0–3 skills with confidence; run via `TagConversationSkillsJob`
- `app/services/openai/SkillCatalog` — builds the stable catalog prefix for the SkillTagger prompt (promotes prompt caching)
- `app/services/outbound/AdminMessage` — sends a manual admin message (free text or template) to one participant; used by `SendAdminMessageJob` / `BroadcastMessageJob`
- `app/services/copilot/ToolRegistry` — fixed catalog of the ops copilot's read + act tools; hash dispatch (model string never reaches `send`/`eval`); exposes OpenAI function schemas
- `app/services/copilot/ReadTools` — implementations of the copilot's read tools (participant lookup/detail, recent conversations, cohort metrics, failed messages); PII-safe explicit columns (no `coach_notes`/tokens, phone masked)
- `app/services/copilot/AgentRunner` — OpenAI function-calling loop for one copilot turn; executes read tools inline, gates act tools (records a `CopilotPendingAction` and stops), enforces token budget + iteration cap; injection-hardened system prompt
- `app/services/copilot/ActExecutor` — runs an APPROVED act tool through the wrapped service (`Outbound::AdminMessage`, `Participants::DayAdvancer`, status transitions); re-validates args (target → `Participant.kept` by id, bounded body)

## Panel de Administración (Nativo)

- Panel a medida montado en `/admin`, protegido por Devise `AdminUser`.
- Dashboard moderno con métricas clave y actividad reciente de participantes y mensajes.
- Acciones nativas en UI para "Inscribir Participante", "Archivar" (soft-delete vía `discard`), y desarchivar.
- `/admin/prompt_tuning` (superadmin) muestra propuestas de auto-tuning, diff de guardrails, evidencia, aprobar/editar/rechazar y rollback manual.
- `/admin/resources` gestiona el catálogo curado de recursos: alta manual, verificación, approve/reject, re-verificación, descarte e historial de entregas.
- `PromptTuningMailer` avisa por email a superadmins cuando queda una propuesta pendiente.
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
- Models are task-routed via `Openai::ModelRouter`: `gpt-5-nano` for classification/summarization/tagging/clustering, `gpt-5-mini` for user-facing morning/free response and manifesto, audio-specific models for transcription/voice analysis. `openai_model` is only the fallback. Do not use `gpt-5.4-nano`; production rejects it with 400.
- Temperature: `0.75` (generative), `0.3` (JSON summarizer/classifiers). GPT-5-family Chat Completions omit custom temperature and use `max_completion_tokens`.
- CheckinSummarizer uses `response_format: { type: "json_object" }` with fallback if parse fails
- Program-scoped content: `DayContent` belongs to `Program`; `Participant` belongs to `Program`
- `FreeResponseGenerator` keeps safety/privacy/memory in code, but style guardrails come from `Setting.fetch("free_chat_style_guardrails")` with a code fallback.
- Recursos enriquecidos: la IA nunca escribe URLs; solo puede devolver `resource_id` del catálogo. `resource_catalog_enabled`, `resource_autodiscovery_enabled` y `link_preview_enabled` están OFF por defecto; ver `docs/business-rules.md` §30.

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
- Deploy configurado con Kamal en `config/deploy.yml` (`kamal deploy`; migraciones prod con `kamal app exec 'bin/rails db:migrate'`)
- Dry-run prompt preview UI not wired (service supports it: `MorningMessageGenerator.new(...).call(dry_run: true)`)
