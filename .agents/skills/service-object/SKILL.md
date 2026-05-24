---
name: service-object
description: Scaffold a new service object following Piloto Automático conventions. Use when adding business logic that doesn't belong in a model or controller — Whatsapp::, Openai::, or Participants:: namespaces, or a new domain namespace.
---

# Service Object

## When to create one

- Logic spans multiple models.
- External I/O (HTTP, OpenAI, Meta).
- Reused across jobs/controllers.

If it's a single-model concern → instance method on the model.

## Structure

Path: `app/services/<namespace>/<name>.rb`

```ruby
module Namespace
  class Name
    Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)

    def initialize(participant:, day_content:, dry_run: false)
      @participant = participant
      @day_content = day_content
      @dry_run = dry_run
    end

    def call
      # ... build, call, return Result
    end

    private

    attr_reader :participant, :day_content, :dry_run
  end
end
```

## Rules

- One public `#call`. No `#perform`, `#execute`, `#run`.
- Constructor takes keyword args. No positional.
- Private attr_readers, not `@ivars`, in `#call` body.
- Return struct/value object. Don't return `self`.
- Don't rescue exceptions you can't handle — let them bubble to Sidekiq retry.
- HTTP retries belong in the service (see `Whatsapp::Client` exponential-backoff pattern), not the caller.

## AI services specifically

- Prepend `Openai::ProgramManifesto::TEXT` to every system prompt.
- Accept `dry_run: false` keyword — when true, return `Result` with `prompt_used` filled and no API call.
- Use `Openai::Client.new.chat(...)` wrapper, not `OpenAI::Client.new` directly.

## Tests

Mirror path: `spec/services/<namespace>/<name>_spec.rb`.

For AI services: stub with `allow_any_instance_of(described_class).to receive(:call).and_return(Result.new(...))` when testing callers. When testing the service itself, stub the OpenAI client.

For HTTP services: WebMock stubs, not VCR (cassettes only for recorded exploration).

## Examples to mimic

- Generative AI: `app/services/openai/morning_message_generator.rb`
- JSON AI: `app/services/openai/checkin_summarizer.rb`
- HTTP client: `app/services/whatsapp/client.rb`
- State change: `app/services/participants/day_advancer.rb`
