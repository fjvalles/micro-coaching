---
name: background-job
description: Create or modify Sidekiq jobs in Piloto Automático. Covers idempotency, cron fan-out pattern, retry behavior, and scheduling. Use when adding a new job, a cron entry, or fixing a job that duplicates work.
---

# Background Jobs

## Cron fan-out pattern

Two-job split for any time-based broadcast:

```ruby
class MorningWakeJob < ApplicationJob
  def perform
    Participant.kept.active.find_each do |p|
      next unless local_hour_matches?(p, Setting.get("wake_hour"))
      MorningWakeForParticipantJob.perform_later(p.id)
    end
  end
end

class MorningWakeForParticipantJob < ApplicationJob
  def perform(participant_id)
    p = Participant.kept.find(participant_id)
    return if already_sent_today?(p)
    # ... do the work
  end
end
```

- Outer job: cheap filter, runs hourly via sidekiq-cron.
- Inner job: one participant, can retry independently without re-fanning.

## Idempotency

**Always** check before sending:

```ruby
return if Conversation.where(
  participant: p,
  moment: :morning_wake,
  day_number: p.current_day
).exists?
```

A job can fire twice (Sidekiq retries, manual re-enqueue, cron overlap). Duplicate WhatsApp messages = burned user trust.

## Scheduling

`config/schedule.yml` for cron. Hourly tick for time-zone-aware broadcasts (job filters by local hour), daily for global ops.

## Errors

- Don't rescue `StandardError` — let Sidekiq retry with backoff.
- Do rescue specific known transients in the service layer (e.g., 429 in `Whatsapp::Client`).
- For non-retryable inputs (deleted participant): `discard!` the job via early `return`.

## Writing

- ID args only (never AR instances) — serialization is fragile.
- Inherit `ApplicationJob`.
- Name: `<Action><Subject>Job`. Fan-out child: `<Action>For<Subject>Job`.

## Don't

- Don't put business logic in the job — extract to a service, job just orchestrates.
- Don't use `perform_now` in production paths.
- Don't schedule with `wait: X.minutes` if the trigger should be cron-driven — use `schedule.yml`.
