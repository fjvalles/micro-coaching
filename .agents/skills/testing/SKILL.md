---
name: testing
description: Write or extend RSpec tests for Piloto Automático. Covers FactoryBot, WebMock/VCR for external HTTP, OpenAI stubbing, time travel, and coverage strategy across models/services/jobs/requests. Use when adding tests, fixing flaky specs, or auditing coverage of a feature.
---

# Testing

## Run

```bash
asdf exec bundle exec rspec                # full suite
asdf exec bundle exec rspec spec/services  # one dir
asdf exec bundle exec rspec spec/jobs/morning_wake_job_spec.rb:42  # one example
```

## Stack

- RSpec + FactoryBot + VCR + WebMock.
- WebMock blocks all external HTTP (localhost allowed). No real Meta/OpenAI calls in CI.
- `travel_to` (Rails), never Timecop.

## Coverage matrix per feature

When adding a feature, write tests in **all relevant layers**:

| Layer | Tests |
|-------|-------|
| Model (`spec/models/`) | validations, scopes (`.kept`, soft-delete), state transitions, jsonb defaults |
| Service (`spec/services/`) | happy path, edge case, external-call stub, dry-run path if AI |
| Job (`spec/jobs/`) | enqueues correctly, idempotency (run twice = one effect), error path |
| Request (`spec/requests/`) | signature verification, auth, enqueues job, status codes |

A PR that adds a service + job + webhook handler should touch 3–4 spec dirs. If only one, ask why.

## OpenAI stubbing

```ruby
allow_any_instance_of(Openai::MorningMessageGenerator).to receive(:call).and_return(
  Openai::MorningMessageGenerator::Result.new(
    body: "fake message",
    prompt_used: "...",
    tokens_input: 100,
    tokens_output: 50,
    model: "gpt-4.1-mini"
  )
)
```

No cassettes needed. To explore real responses one-off: `VCR.use_cassette("name") { ... }` and **don't commit** sensitive cassettes.

## Meta API stubbing

WebMock:

```ruby
stub_request(:post, %r{graph\.facebook\.com/.*/messages})
  .to_return(status: 200, body: { messages: [{ id: "wamid.x" }] }.to_json)
```

## Idempotency tests (jobs)

```ruby
it "is idempotent" do
  2.times { described_class.new.perform(participant.id) }
  expect(Conversation.where(moment: :morning_wake).count).to eq(1)
end
```

Always test this for any job that sends WhatsApp.

## Time-sensitive tests

```ruby
travel_to(Time.zone.parse("2026-05-23 08:00 -06:00")) do
  # ...
end
```

For cron filter logic, test boundary hours (off-by-one is the common bug).

## Factories

`spec/factories/`. One factory per model. Use traits for variants:

```ruby
factory :participant do
  phone_e164 { "+5215555555555" }
  status { :pending }
  trait :active do
    status { :active }
    enrolled_at { Time.current }
  end
end
```

## Coverage gaps to check

- Soft-delete: query without `.kept` returning discarded record = bug. Test the `.kept` filter.
- Signature mismatch: webhook with bad `X-Hub-Signature-256` → 401.
- JSON parse fallback: malformed AI response → degraded but no raise.
- Locale env: changing `PROGRAM_LOCALE` affects template send.

## Don't

- Don't hit real APIs in CI.
- Don't stub at HTTP level when service-level stub is cleaner.
- Don't share state across examples (no `before(:all)` for mutable data).
- Don't skip request specs — they're the only thing that exercises auth + signature.
