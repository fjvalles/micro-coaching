---
name: "source-command-analyze-prompts"
description: "Analyze logged prompts + tool usage to propose skill/hook improvements"
---

# source-command-analyze-prompts

Use this skill when the user asks to run the migrated source command `analyze-prompts`.

## Command Template

Read `.Codex/prompt-log/*.jsonl` (most recent 2 months). Each line is JSON with `ts`, `type` (`prompt` or `tool`), `session`, and either `prompt` or `tool`/`skill`/`agent`.

Produce a markdown report and write it to `.Codex/prompt-log/insights-$(date +%Y-W%V).md`. Overwrite if exists.

Report sections:

1. **Volumen** — total prompts, prompts/session avg, top 5 active days.
2. **Patrones repetidos** — cluster prompts by intent (rough — verbs + nouns). List clusters with ≥3 occurrences. For each: example prompt, count, candidate skill name.
3. **Skills disparados** — count by skill name. Flag skills triggered <2× (possible bad description) and verbs in prompts that never triggered any skill (possible missing skill).
4. **Fricción** — prompts within 90s of previous prompt in same session (likely corrections). List the pair (previous tool call + corrective prompt) with count. Flag tools/skills that appear often before a correction.
5. **Agentes** — count `Agent` invocations by `subagent_type`. Flag subagents used <2× (low value) vs >10× (consider promoting to skill).
6. **Recomendaciones concretas** — bulleted, actionable:
   - "Crear skill X para tarea Y (visto N veces)"
   - "Editar description de skill Z — disparado solo K veces aunque hay N prompts relevantes"
   - "Agregar hook PreToolUse W para evitar fricción F"
   - "Promover comando manual M a slash command"

Keep recomendaciones priorizadas por impacto (frecuencia × token cost estimado).

Si log vacío o <10 prompts: di "insuficiente data, espera más uso" y termina.

No edites ningún archivo fuera de `.Codex/prompt-log/`. No instales skills ni hooks tú — solo recomienda.
