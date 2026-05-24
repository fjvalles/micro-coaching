---
name: openai-service
description: Build or modify OpenAI service objects in Piloto Automático. Covers prompt caching pattern, JSON-mode with fallback, dry-run support, temperature defaults, and token accounting. Use when adding AI generation, modifying prompts, or debugging token usage.
---

# OpenAI Service

## Model + temps

- Model: `gpt-4.1-mini` (constant in service, not env).
- Temperature: `0.75` generative, `0.3` JSON/summarizer.

## Prompt caching (critical)

OpenAI caches a system prompt if reused ≥1024 tokens within ~5 min. Maximize hit rate:

```ruby
system_prompt = [
  Openai::ProgramManifesto::TEXT,   # shared, ~1.2k tokens, always first
  day_content.ai_system_prompt,     # day-specific
  participant_context(participant)  # variable last
].join("\n\n")
```

Order matters: shared/cacheable content first, variable last. Never interpolate participant name into the manifesto block.

## JSON responses

```ruby
response = client.chat(
  parameters: {
    model: MODEL,
    temperature: 0.3,
    response_format: { type: "json_object" },
    messages: [...]
  }
)

raw = response.dig("choices", 0, "message", "content")
parsed = JSON.parse(raw)
{ summary: parsed["summary"], key_pattern: parsed["key_pattern"] }
rescue JSON::ParserError
  { summary: raw, key_pattern: nil }   # always degrade, never raise
```

## Dry run

Every generator supports prompt preview without API spend:

```ruby
def call(dry_run: false)
  prompt = build_prompt
  return Result.new(prompt_used: prompt, body: nil, ...) if dry_run
  # ... real call
end
```

Useful for admin preview, tests, and prompt iteration.

## Result struct

Every AI service returns:

```ruby
Result = Struct.new(:body, :prompt_used, :tokens_input, :tokens_output, :model, keyword_init: true)
```

Token counts come from `response["usage"]` — record them; useful for cost dashboards later.

## Testing

- Stub the client, not HTTP: `allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return(fake_response)`.
- Test JSON fallback path explicitly (return malformed string, assert no raise).
- Test dry-run path returns prompt without calling client (`expect(client).not_to receive(:chat)`).

## Adding a new generator

1. New file `app/services/openai/<name>_generator.rb` — copy `morning_message_generator.rb` skeleton.
2. Prepend `ProgramManifesto::TEXT`.
3. Add `dry_run:` arg.
4. Return `Result`.
5. Mirror spec with stubbed client.
