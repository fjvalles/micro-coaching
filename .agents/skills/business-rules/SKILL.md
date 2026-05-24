---
name: business-rules
description: Maintain docs/business-rules.md as canonical source of Piloto Automático business logic. Use when adding/changing/removing a rule, when reviewing a PR that touches participant/conversation/job/AI logic, or when an agent needs the authoritative answer about how the program behaves.
---

# Business Rules — maintenance

Canonical doc: **`docs/business-rules.md`**.

This skill governs *how to keep it accurate*. The doc itself is the source — read it first when answering any "how does X work?" question about the product.

## Rule entry format

Every rule has three parts. No exceptions.

```markdown
### N.M Short name
- **Regla.** <declarative statement, present tense, ≤2 lines>
- **Por qué.** <rationale — constraint, policy, decision link>
- **Enforce.** <path:line, or multiple, or "no enforcement (manual)">
```

If you can't fill all three, the rule isn't ready. Either find the enforcement point in code or move it to `docs/decisions.md` as a pending question.

## When to update

| Trigger | Action |
|---------|--------|
| Adding new logic (job, classifier branch, state transition) | Add new rule in correct section |
| Changing existing logic | Edit `Regla` + `Enforce` line of that rule |
| Removing logic | Strikethrough rule + reference to `docs/decisions.md` entry explaining why |
| Refactor moves enforcement to new file | Update `Enforce` `path:line` |
| New env var or `Setting` key | Add to §12 Configuración |
| New `Conversation.moment` enum value | Update §11 + classifier rules |
| New participant `status` | Update §3.1 enum + add transition rules |

## Sections (current)

1. Programa — duración, fases, completion
2. Enrollment — cómo se crea un participante
3. Estados — enum + transitions
4. Cadencia diaria — cron, timing
5. Avance de día — DayAdvancer logic
6. Mensajería entrante — webhook → job
7. Clasificación inbound — MessageClassifier branches
8. Comunicación saliente — WhatsApp policy + templates
9. Idempotencia de jobs — duplicate prevention
10. Generación con IA — OpenAI rules
11. Persistencia de mensajes — Conversation invariants
12. Configuración vía Setting — runtime knobs
13. Edge cases conocidos — explicit acceptances

New domain? New top-level section. Renumber consistently.

## Review checklist (PR-time)

When reviewing any PR that touches `app/models/{participant,conversation,program,day_content,daily_report}`, `app/services/participants/`, `app/services/openai/`, `app/jobs/`, or `app/controllers/webhooks_controller`:

- [ ] Does the diff change observable behavior of the program?
- [ ] If yes → is `docs/business-rules.md` updated in the same PR?
- [ ] Are `Enforce` lines still pointing to live `path:line`?
- [ ] Is a removed rule actually deleted from the doc (strikethrough + docs/decisions.md note)?

If a PR changes business logic without touching the doc, bounce it.

## Anti-patterns

- **Rules without enforcement.** "Participants should X" with no `Enforce` line = wishful thinking. Either implement and link, or drop.
- **Restating obvious code.** "`Participant has phone_e164 column`" is not a rule. Rules describe **behavior + policy**, not schema.
- **Duplication.** If a rule appears in two sections, one must reference the other.
- **Linking to PRs/tickets in `Enforce`.** Files rot slower than tracker URLs. `path:line` only.
- **Soft language.** "Usually", "typically", "in most cases" → either it's a rule or it's an edge case (§13). Pick.

## When the doc and code disagree

The **code wins**. Update the doc immediately and flag in commit message:

```
docs(business-rules): correct §5.1 — DayAdvancer uses local date, not UTC

Doc said UTC; code at day_advancer.rb:15 uses local. Code is correct
(participants in different TZs would otherwise skip days).
```

Never silently "fix" the code to match the doc without checking which is intentional. Likely the code knows something the doc forgot.

## Relation to other docs

- `AGENTS.md` — architecture + how-to-run. Links to this doc.
- `docs/decisions.md` — *why we chose* (one-time). This doc = *what we do* (standing).
- `docs/adr/` — long-form design proposals before they become rules.
- Inline comments — only when WHY isn't obvious *at the point of code*.

A new rule may originate as an ADR → become a `docs/decisions.md` bullet → land as a rule here once implemented.
