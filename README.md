# Impulso by Comtraining (codename: Piloto Automático)

Rails 7.2 app that runs a 14-day WhatsApp micro-coaching program for leadership,
change, and behavioral follow-through. It sends scheduled morning prompts and
nightly check-ins, processes replies with OpenAI, and exposes a Spanish-language
native admin panel for operators.

## Stack

- Ruby 4.0.2 / Rails 7.2.x
- PostgreSQL 16
- Redis 7
- Sidekiq 7 + sidekiq-cron
- Hotwire (Turbo + Stimulus)
- native Rails admin UI
- WhatsApp Cloud API (Meta, direct)
- OpenAI (`gpt-4.1-mini`)
- RSpec + FactoryBot + WebMock + VCR

## Local setup

```bash
# Services
brew install postgresql@16 redis
brew services start postgresql@16
brew services start redis

# App
asdf install ruby 4.0.2
bundle install
cp .env.example .env   # then fill in keys
asdf exec bundle exec rails db:create db:migrate db:seed
asdf exec bundle exec foreman start -f Procfile.dev
```

Sidekiq:
```bash
asdf exec bundle exec sidekiq
```

Tests:
```bash
asdf exec bundle exec rspec
```

## Environment variables

See `.env.example`.

- `OPENAI_API_KEY`
- `META_PHONE_NUMBER_ID`, `META_BUSINESS_ACCOUNT_ID`, `META_ACCESS_TOKEN`,
  `META_APP_SECRET`, `META_WEBHOOK_VERIFY_TOKEN`, `META_API_VERSION`
- `ADMIN_EMAIL`, `ADMIN_PASSWORD` — seeded on first `db:seed`
- `DEFAULT_TIMEZONE`, `PROGRAM_LOCALE`

## Meta Cloud API setup

1. Create a Meta Business account at `business.facebook.com`.
2. Create a WhatsApp Business app at `developers.facebook.com`.
3. Add and verify a phone number; copy `META_PHONE_NUMBER_ID`.
4. Generate a permanent System User access token (`META_ACCESS_TOKEN`).
5. Get the app secret (`META_APP_SECRET`).
6. Configure webhook:
   - Callback URL: `https://<your-ngrok>.ngrok.io/webhooks/whatsapp`
   - Verify token: same random string set in `META_WEBHOOK_VERIFY_TOKEN`
   - Subscribed fields: `messages`
7. Submit utility templates for Meta approval:
   - `bienvenida_piloto` — variables: `{{1}}` name
   - `despertar_dia_01` … `despertar_dia_14` — `{{1}}` name, `{{2}}` body
   - `iareto_dia_01` … `iareto_dia_14` — `{{1}}` name, `{{2}}` body
   - `checkin_dia_01` … `checkin_dia_14` — `{{1}}` name, `{{2}}`–`{{4}}` questions
   Templates take 1–24h to be approved.

### Local webhook (ngrok)

```bash
ngrok http 3000
# Use the https URL in the Meta dashboard webhook config.
```

## Admin panel

`/admin` — Devise-protected native admin. Log in with the seeded admin.

Create a participant via the "Inscribir Participante" flow or the Participants
section. `SendWelcomeJob` enqueues the welcome template and the initial pattern
question.

## Scheduled jobs

`config/schedule.yml` is loaded by `sidekiq-cron`:

- `MorningWakeJob` — hourly, sends Despertar AM at 07:00 participant-local
- `CheckinEveningJob` — hourly, sends check-in at 20:00 participant-local
- `AdvanceDayJob` — daily 06:00 UTC, advances `current_day` for those who completed yesterday's check-in

## Out of scope this phase

- Payment gateway (manual enrollment only)
- Deployment (local dev + ngrok only)
- Voice transcription (voice messages get an automated "solo texto" reply)
- Multi-tenant (one admin, one program)

## Commercial docs

The repo includes commercial planning docs used to validate the B2B launch:

- `docs/commercial-strategy.md`
- `docs/lean-canvas.md`
- `docs/dvf-analysis.md`
- `docs/customer-interviews.md`
- `docs/offer-hormozi.md`
- `docs/brand-positioning.md`

## Seeded programs

`db/seeds/day_contents.rb` now provisions three 14-day programs that match the
current B2B positioning:

- `impulso-liderazgo-en-accion`
- `impulso-cambio-en-accion`
- `impulso-productividad-sostenible`

See `docs/decisions.md` for autonomous choices made during build.
