# Impulso by Comtraining

Rails 7.2 app that runs a 14-day WhatsApp micro-coaching program for leadership,
change, and behavioral follow-through. Sends scheduled morning prompts and nightly
check-ins, processes text/voice replies with OpenAI, and exposes a Spanish-language
native admin panel for operators.

## Stack

- Ruby 4.0.2 / Rails 7.2.x
- PostgreSQL 16
- Redis 7
- Sidekiq 7 + sidekiq-cron
- Hotwire (Turbo + Stimulus)
- Native Rails admin UI (Devise-protected)
- WhatsApp Cloud API (Meta, direct)
- OpenAI (`gpt-4.1-mini` + Whisper for voice)
- RSpec + FactoryBot + WebMock + VCR

## Local setup

**Prerequisites:** install PostgreSQL 16 and Redis via Homebrew, then start them:

```bash
brew install postgresql@16 redis
brew services start postgresql@16
brew services start redis
```

**App:**

```bash
asdf install ruby 4.0.2
bundle install
cp .env.example .env   # fill in all keys (see section below)
asdf exec bundle exec rails db:create db:migrate db:seed
asdf exec bundle exec foreman start -f Procfile.dev
```

> Always prefix commands with `asdf exec bundle exec` — bare `bin/rails` picks the wrong Ruby.

**Tests:**

```bash
asdf exec bundle exec rspec
```

## Environment variables

Copy `.env.example` → `.env`. All variables below are required unless marked optional.

| Variable | Purpose |
|----------|---------|
| `OPENAI_API_KEY` | OpenAI API |
| `META_PHONE_NUMBER_ID` | Meta Cloud API phone number |
| `META_BUSINESS_ACCOUNT_ID` | Meta business account |
| `META_ACCESS_TOKEN` | Meta permanent System User token |
| `META_APP_SECRET` | Webhook signature verification |
| `META_WEBHOOK_VERIFY_TOKEN` | Webhook challenge handshake |
| `META_API_VERSION` | Default `v21.0` |
| `PROGRAM_LOCALE` | WhatsApp template locale, default `es_MX` |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Seeded admin credentials |
| `ADMIN_NAME` | Seeded admin display name (default `"Admin"`) |
| `GOOGLE_DRIVE_BACKUP_FOLDER_ID` | Drive folder for daily DB dumps (share with service account) |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Full JSON string of service account credentials (scope: `drive.file`) |
| `RESEND_API_KEY` | Resend API key for transactional email |
| `APP_HOST` | Production domain (default: `impulso.comtraining.cl`) |
| `MAILER_FROM` | From address (default: `Impulso <noreply@impulso.comtraining.cl>`) |

## Meta Cloud API setup

1. Create a Meta Business account at `business.facebook.com`.
2. Create a WhatsApp Business app at `developers.facebook.com`.
3. Add and verify a phone number; copy `META_PHONE_NUMBER_ID`.
4. Generate a permanent System User access token → `META_ACCESS_TOKEN`.
5. Get the app secret → `META_APP_SECRET`.
6. Configure webhook:
   - Callback URL: `https://<your-domain>/webhooks/whatsapp`
   - Verify token: same string in `META_WEBHOOK_VERIFY_TOKEN`
   - Subscribed fields: `messages`
7. Submit utility templates for Meta approval (takes 1–24 h):
   - `bienvenida_piloto` — `{{1}}` name
   - `despertar_dia_01` … `despertar_dia_14` — `{{1}}` name, `{{2}}` body
   - `iareto_dia_01` … `iareto_dia_14` — `{{1}}` name, `{{2}}` body
   - `checkin_dia_01` … `checkin_dia_14` — `{{1}}` name, `{{2}}`–`{{4}}` questions

### Local webhook (ngrok)

```bash
ngrok http 3000
# Paste the https URL into the Meta dashboard webhook config.
```

## Admin panel

`/admin` — Devise-protected. Log in with the seeded admin credentials.

- Create participants via "Inscribir Participante" — triggers `SendWelcomeJob`.
- View conversation transcripts (including voice analysis) per participant.
- Audit prompts at `/admin/prompt_templates`.
- Browse internal docs at `/admin/docs`.
- Access Sidekiq dashboard at `/sidekiq`.

## Scheduled jobs

Defined in `config/schedule.yml`, loaded by `sidekiq-cron`:

| Job | Schedule | What it does |
|-----|----------|-------------|
| `MorningWakeJob` | Hourly | Fans out to `MorningWakeForParticipantJob` for participants whose local hour == `Setting.get("wake_hour")` |
| `CheckinEveningJob` | Hourly | Same pattern at 20:00 participant-local time |
| `AdvanceDayJob` | Daily 06:00 UTC | Calls `Participants::DayAdvancer` |
| `DailyBackupJob` | Daily 03:00 UTC | `pg_dump` → uploads to Backblaze B2 (S3), prunes backups > 7 days |

## Voice messages

Inbound voice notes are processed automatically:

1. `Whatsapp::MediaFetcher` downloads the audio from Meta.
2. `Openai::AudioTranscriber` (Whisper / `gpt-4o-mini-transcribe`) returns text + language + duration.
3. `Openai::VoiceAnalyzer` (`gpt-4o-mini-audio-preview`) infers tone, energy, and pace.
4. Transcription and `voice_analysis` JSON are persisted on the `Conversation` record.

Requires `ffmpeg` locally for ogg→mp3 transcode. Missing `ffmpeg` skips voice analysis gracefully.

## Seeded programs

`db/seeds/day_contents.rb` provisions three 14-day programs:

- `impulso-liderazgo-en-accion`
- `impulso-cambio-en-accion`
- `impulso-productividad-sostenible`

## Key docs

| Doc | Path |
|-----|------|
| Business rules (canonical) | `docs/business-rules.md` |
| Architecture & flows | `docs/architecture-flows.md` |
| Past decisions | `docs/decisions.md` |
| Pedagogy / See-Choose-Anchor | `docs/pedagogy-coaching.md` |
| Admin guide | `docs/admin-guide.md` |

All docs also render at `/admin/docs`.

## Out of scope (current phase)

- Payment gateway (manual enrollment only)
- Deployment config (Kamal/Heroku/Render not set up; dev via ngrok)
- WhatsApp template auto-submission (manual via Meta dashboard)
