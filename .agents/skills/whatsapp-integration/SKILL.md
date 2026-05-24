---
name: whatsapp-integration
description: Work with Meta WhatsApp Cloud API in Piloto Automático — templates, webhooks, signature verification, free-form sends. Use when adding a new template, debugging webhook delivery, modifying send logic, or handling new inbound message types.
---

# WhatsApp Integration

## Architecture

```
Meta → POST /webhooks/whatsapp
  → SignatureVerifier (X-Hub-Signature-256, secure_compare)
  → InboundParser (payload → messages[], statuses[])
  → ProcessIncomingMessageJob (per message)
    → Participants::MessageClassifier
    → handler service (CheckinSummarizer / FreeResponseGenerator)
    → Whatsapp::Client#send_text
```

## Templates vs. free-form

- **Free-form** (`send_text`): allowed only inside 24h customer-service window after user's last inbound. Used for all AI replies during active conversation.
- **Template** (`send_template` via `TemplateSender`): required outside window. Used for morning wake, IAReto, check-in broadcasts.

Templates use generic `{{1}}`, `{{2}}` placeholders. 4 templates cover all 14 days:
- `bienvenida`
- `despertar_dia_NN` (param: AI-generated body)
- `iareto_dia_NN`
- `checkin_dia_NN`

Locale via `ENV["PROGRAM_LOCALE"]` (default `es_MX`).

## Adding a new template

1. Submit in Meta Business Manager dashboard (manual, no API).
2. Wait for approval (minutes–hours).
3. Add helper method in `Whatsapp::TemplateSender`.
4. Call from job, never from controller.

## Inbound classification

`Participants::MessageClassifier` returns one of:
- `:initial_pattern_answer` — first reply after welcome
- `:checkin_response` — within `pending_checkin_at` window
- `:free_user` — anything else

Don't add new categories without updating the classifier + `ProcessIncomingMessageJob` dispatch.

## Media

Media (`media_id` payloads) currently rejected with text prompt asking for typed reply. No voice transcription. Don't add Whisper without checking `docs/decisions.md` first.

## Signature verification

**Never** skip. `SignatureVerifier` uses `secure_compare` to prevent timing attacks. Tests must include a signature-mismatch case returning 401.

## Client retries

`Whatsapp::Client` retries 3× on 429/5xx with exponential backoff. Don't wrap callers in retry loops.

## Environment

Required env vars (see `AGENTS.md`):
- `META_PHONE_NUMBER_ID`, `META_BUSINESS_ACCOUNT_ID`, `META_ACCESS_TOKEN`
- `META_APP_SECRET` (signature verification)
- `META_WEBHOOK_VERIFY_TOKEN` (challenge handshake)
- `META_API_VERSION` (default `v21.0`)

## Don't

- Don't call Meta from the request cycle — always enqueue.
- Don't construct payloads inline — use `Client#send_text` / `TemplateSender`.
- Don't log full `META_ACCESS_TOKEN`.
- Don't bypass `.kept` when fetching the participant for an inbound message.
