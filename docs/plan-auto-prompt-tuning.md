# Plan de implementación — Auto-mejora de prompts conversacionales sin intervención

> Estado: **propuesta**. No implementado. Kill-switches OFF por defecto.
> Objetivo: automatizar el ciclo que hoy se hace a mano (leer conversaciones →
> detectar anti-patrones → editar guardrails del prompt → desplegar), de modo que
> el sistema **detecte, proponga y —opcionalmente— aplique** mejoras al prompt de
> chat libre **sin que un humano tenga que intervenir**, con medición y rollback
> automáticos como red de seguridad.
>
> Origen: análisis manual de la conversación con Catalina (día 1), que reveló loop
> somático, acuses repetidos ("Gracias por decirlo"), preguntas compuestas e
> insistencia contra la autonomía. La corrección fue manual (editar
> `FreeResponseGenerator`, commit, deploy). Este plan vuelve ese ciclo autónomo.

---

## 0. Hallazgo arquitectónico que condiciona todo

El prompt vivo de chat libre **vive en código** (heredoc en
`Openai::FreeResponseGenerator#system_prompt`) más el `program_manifesto` (un
`Setting`). El infra existente de prompts —`PromptTemplate` / `PromptVersion` /
`PromptExecution` / `Openai::PromptCritic`— es un **espejo de logging**, no la
fuente del prompt:

- `PromptLogger#sync_version` **sobrescribe** `PromptTemplate.current_body` con lo
  que el servicio generó en cada ejecución.
- `PromptCritic` produce un `suggested_body` que se guarda en `prompt_analyses` y
  se revisa a mano en `/admin/prompt_templates`. **Nunca se aplica** y, aunque se
  aplicara a `current_body`, el runtime no lo leería.

**Consecuencia:** ninguna automatización puede cambiar el comportamiento sin un
deploy mientras los guardrails estén hardcodeados en Ruby. **El keystone del plan
es mover el bloque de guardrails a una capa editable en runtime.** Sin eso, el
resto es teatro.

---

## 1. Principios de diseño (no negociables)

1. **Sólo se auto-edita un bloque acotado.** El auto-tuner toca **únicamente** el
   bloque "Estilo de conversación" (guardrails de estilo). El bloque de seguridad
   /privacidad (anti-inyección, no filtrar datos, no revelar metodología) y la
   inyección de memoria (`focus_hint`, `ai_summary`) **permanecen en código y son
   inmutables** para la automatización.
2. **Heurística decide, LLM sólo propone.** La decisión de aplicar/revertir se basa
   en un score determinista (sin LLM en el camino de control) → reproducible,
   barato, auditable. El LLM aporta redacción de mejoras, no la decisión.
3. **Todo cambio es reversible y auditado.** Cada edición crea una versión
   (`origin: "auto_tuner"`) con el diff, el score que la motivó y un rationale.
4. **Medición antes de confiar.** Un cambio sólo "se queda" si el score no empeora
   en la ventana siguiente; si empeora, **rollback automático**.
5. **Cambio acotado y con cooldown.** Máx. 1 cambio aplicado por semana; diffs
   grandes (rewrite total) se rechazan; longitud del bloque topada.
6. **Defensa contra inyección de prompt.** El texto del participante entra al
   analizador **sólo como dato citado y truncado**, nunca como instrucción. El
   candidato generado pasa validación dura (sin URLs, sin PII, sin instrucciones
   que contradigan el bloque de seguridad).
7. **Kill-switch + modo gradual.** `auto_prompt_tuning_enabled` (default OFF) y
   `auto_prompt_tuning_mode` ∈ `observe | propose | apply` (default `observe`).
   "Sin intervención" es el destino (`apply`), pero se llega por escalones.

---

## 2. Arquitectura propuesta

```
Cron semanal → AutoPromptTuningJob (gated)
   │
   ├─ 1. Muestrear conversaciones recientes (chat libre, N participantes, ventana)
   │
   ├─ 2. Conversations::QualityScorer  ── heurística determinista ──► score 0-100
   │        · preguntas compuestas / nº "?" por turno
   │        · acuses repetidos (n-gram entre turnos consecutivos)
   │        · loop somático (léxico corporal en turnos seguidos)
   │        · asimetría (largo IA ≫ largo usuario)
   │        · cap golpeado con usuario enganchado
   │        · insistencia (misma pregunta repetida)
   │
   ├─ 3. Si score < umbral Y modo ≠ observe:
   │        Openai::GuardrailProposer (JSON mode, analizador sin manifesto)
   │        ── findings + delta de guardrails (append/modify acotado) ──►
   │
   ├─ 4. Guardrails::Validator (dura): longitud, ancla requerida, sin URL/PII,
   │        diff acotado, no toca bloque seguridad
   │
   ├─ 5. modo apply → Settings.set("free_chat_style_guardrails", nuevo)
   │        + PromptVersion(origin:"auto_tuner") + audit + Sentry breadcrumb
   │        modo propose → guarda candidato para revisión en admin, no aplica
   │
   └─ 6. Ventana siguiente: recomputar score. Si regresó vs baseline → revert
            automático a la versión previa (cooldown semanal).
```

El runtime cambia porque `FreeResponseGenerator#system_prompt` **interpola el
`Setting` `free_chat_style_guardrails`** en lugar del heredoc fijo.

---

## 3. Fases de implementación

### Fase 0 — Enabler: guardrails editables en runtime (sin esto, nada)

- Nuevo `Setting` `free_chat_style_guardrails` (type `:text`), sembrado con el
  bloque "Estilo de conversación" actual (ya en `free_response_generator.rb`).
- `FreeResponseGenerator#system_prompt` interpola
  `Setting.fetch("free_chat_style_guardrails")` en vez del texto fijo. El bloque
  de seguridad/privacidad y la inyección de memoria **siguen en código**.
- Editable a mano en `/admin/settings` desde ya (beneficio inmediato: tunear
  estilo sin deploy, que es justo lo que hoy obliga a desplegar).
- Tests: el prompt incluye el contenido del Setting; fallback si está vacío.

**Entregable independiente y útil aunque no se haga el resto.**

### Fase 1 — Medición: `Conversations::QualityScorer` (heurística pura)

- Servicio determinista que recibe un conjunto de `Conversation` (chat libre,
  `.kept`, role user/assistant) y devuelve un `Result` con score global 0-100 +
  sub-scores + ejemplos ofensores (para el rationale). **Cero tokens.**
- Detectores v1 (todos regex/conteo, en español):
  - **Preguntas compuestas:** >1 "?" en un turno assistant, o patrón
    `¿…(y|o)…\?` → penaliza.
  - **Acuses repetidos:** n-gram inicial repetido en turnos assistant
    consecutivos (p. ej. "Gracias por", "Perfecto,").
  - **Loop somático:** léxico corporal (`cuerpo|garganta|pecho|respiración|
    sensación|pesadez|tensión`) en ≥3 turnos assistant seguidos.
  - **Asimetría:** `len(assistant) / len(user)` por par; promedio alto penaliza.
  - **Cap con enganche:** `free_inbounds_today` tocó el cap el mismo día con
    actividad sostenida (señal de que el cap cortó momentum).
  - **Insistencia:** misma pregunta/intención repetida tras respuesta del usuario.
- Cada detector pesa y se normaliza a 0-100. Umbrales en `Setting`s
  (`auto_tuning_score_threshold`, etc.).
- Materializa un `ConversationQualityScore` (tabla nueva, UUID PK) por corrida
  para tener serie temporal → habilita comparar baseline vs post-cambio.

### Fase 2 — Propuesta: `Openai::GuardrailProposer` (LLM, sólo redacta)

- Reusa el patrón de `ParticipantSummarizer` (analizador interno, **sin**
  `ProgramManifesto`, JSON mode, `temperature: 0.3`, prompt-caching del catálogo
  de reglas como prefijo estable).
- Input: bloque de guardrails actual + findings del Scorer + 3-5 ejemplos
  ofensores **citados y truncados** entre etiquetas (anti-inyección).
- Output JSON acotado: `{ findings, proposed_guardrails, rationale, change_kind }`
  donde `change_kind ∈ {append_bullet, tighten_bullet, no_change}`.
- **No reescribe el bloque entero**: opera por viñeta para que el diff sea chico y
  revisable.

### Fase 3 — Aplicación segura: `Guardrails::Validator` + auto-apply + rollback

- **Validator (gate duro, sin esto no se aplica nada):**
  - Longitud ≤ tope (`auto_tuning_max_guardrails_chars`).
  - Conserva anclas obligatorias (1 pregunta por mensaje; respeta autonomía).
  - Sin URLs, sin teléfonos/PII, sin nombres propios de participantes.
  - Diff acotado: rechaza si cambia > X% del bloque (anti rewrite total).
  - No contiene instrucciones que contradigan el bloque de seguridad.
- **Apply (sólo modo `apply`):** `Setting.set` + `PromptTemplate.record_version!`
  (o tabla `prompt_tuning_runs`) con `origin:"auto_tuner"`, diff, score motivador,
  rationale. Append-only, totalmente reversible.
- **Canary + auto-rollback:** tras aplicar, marca `baseline_score`. En la corrida
  siguiente, si `nuevo_score < baseline_score − margen` → revertir al guardrail
  previo y marcar la propuesta como fallida (no reintentar la misma). Cooldown:
  máx. 1 cambio aplicado / semana.

### Fase 4 — Orquestación: `AutoPromptTuningJob` + cron + admin

- Job idempotente (1 corrida por ventana; chequea `prompt_tuning_runs` del
  período). Gated por `auto_prompt_tuning_enabled` + `auto_prompt_tuning_mode`.
- `config/schedule.yml`: semanal (p. ej. `0 4 * * 1`). En `observe` corre sólo el
  Scorer (gratis) y registra serie temporal.
- Admin en `/admin/prompt_tuning` (detalle de UX en §6).
- Sentry breadcrumb en cada apply/rollback.

### Fase 5 — Notificación push (cierra el "fácil de aprobar")

- Al generar un candidato en modo `propose`, avisar al admin por **WhatsApp y/o
  email** (reusar `Whatsapp::Client` / Resend) con resumen + deep-link directo a
  la propuesta. Modelo *push*, no *pull*: no hay que acordarse de entrar al panel.
- El mensaje no aplica nada; sólo enlaza. Aprobar siempre ocurre en el panel
  autenticado.

---

## 4. Settings nuevos

| Key | Tipo | Default | Para qué |
|-----|------|---------|----------|
| `free_chat_style_guardrails` | text | bloque actual | Guardrails editables en runtime (Fase 0) |
| `auto_prompt_tuning_enabled` | boolean | `false` | Kill-switch maestro |
| `auto_prompt_tuning_mode` | string | `observe` | `observe`/`propose`/`apply` |
| `auto_tuning_score_threshold` | integer | 70 | Bajo esto, propone mejora |
| `auto_tuning_rollback_margin` | integer | 5 | Caída de score que dispara revert |
| `auto_tuning_max_guardrails_chars` | integer | 1500 | Tope de longitud del bloque |
| `auto_tuning_sample_size` | integer | 30 | Conversaciones muestreadas por corrida |

---

## 5. Interfaz de aprobación (modo `propose`)

El modo `propose` es donde vive la aprobación humana, así que la UI debe hacer
**decidir en segundos**, no leer un informe. Pantalla `/admin/prompt_tuning`:

### Vista de cola

- Lista de propuestas `pending` (badge en el nav cuando hay ≥1). Cada fila:
  fecha, score que la motivó, `change_kind`, una línea de rationale.

### Vista de detalle (la pantalla de decisión)

1. **Diff antes/después** del bloque de guardrails, resaltado a nivel de viñeta
   (verde añadido / rojo quitado). El cambio es chico por diseño (§3, opera por
   viñeta), así que se lee de un vistazo.
2. **Por qué** — findings del Scorer + sub-scores que cruzaron umbral.
3. **Evidencia** — 2-3 **ejemplos reales ofensores** citados (mensajes IA que
   dispararon el detector), para que la decisión se base en datos, no en fe.
4. **Acciones (un clic):**
   - **Aprobar** → aplica el candidato (mismo camino que modo `apply`:
     `Setting.set` + `PromptVersion(origin:"auto_tuner")` + audit). Entra el canary
     + auto-rollback de §3.
   - **Editar y aprobar** → textarea editable con el candidato precargado; el
     humano ajusta la redacción y aprueba. Pasa por el mismo `Validator`.
   - **Rechazar** → descarta; marca la propuesta para no reintentar la misma.

### Lo que la hace "fácil"

- **Push, no pull** (§ Fase 5): llega aviso por WhatsApp/email con deep-link; no
  hay que recordar entrar.
- **Diff acotado**: nunca un rewrite de pantalla completa que obligue a releer
  todo el prompt.
- **Reversible sin miedo**: aprobar no es definitivo — el canary revierte solo si
  el score empeora, y siempre hay botón "revertir" manual en el historial.
- **Mismo gate para todos los caminos**: aprobación manual, edición y auto-apply
  pasan por el mismo `Validator`, así que el humano nunca puede meter algo que el
  modo autónomo rechazaría (y viceversa).

> Migración de confianza: se empieza en `propose` (humano aprueba todo), se mira
> el historial; cuando las aprobaciones son consistentemente "sí", se pasa a
> `apply`. La misma UI sirve de bitácora para esa decisión.

---

## 6. Por qué NO el camino fácil

- **¿Por qué no dejar que un LLM reescriba todo el system prompt solo?** Riesgos:
  inyección desde el texto del participante, regresión de calidad sin detección,
  drift, pérdida de invariantes de seguridad/privacidad. El diseño bloque-acotado
  + medición determinista + rollback es la versión responsable de "sin
  intervención".
- **¿Por qué no reusar `PromptCritic` tal cual?** Hace crítica genérica de
  prompt-engineering sobre ejecuciones, revisada por humano, y su salida no puede
  manejar el prompt vivo (problema del espejo). Reusamos su *patrón* (LLM JSON +
  `prompt_analyses`), no el servicio. Conviene además arreglar el espejo: si la
  Fase 0 mueve guardrails a Setting, `PromptCritic` podría apuntar a ese Setting a
  futuro.
- **¿Por qué heurística y no LLM para decidir?** El camino de control debe ser
  barato, determinista y reproducible para correr sin supervisión. El LLM varía y
  cuesta; queda relegado a proponer texto.

---

## 7. Orden de entrega recomendado

1. **Fase 0** (enabler) — valor inmediato: tunear estilo sin deploy. Bajo riesgo.
2. **Fase 1** (Scorer + serie temporal en modo `observe`) — visibilidad de
   calidad conversacional sin tocar nada. Bajo riesgo.
3. **Fase 2 + 3 en modo `propose`** — el sistema sugiere, humano aprueba un clic.
4. **Modo `apply`** — autonomía plena, una vez que la serie histórica muestre que
   las propuestas son buenas y el rollback funciona.

Cada fase es desplegable y reversible por sí sola. "Sin intervención" se activa
sólo cuando los datos de las fases previas lo respaldan.

---

## 8. Pendientes / decisiones abiertas

- ¿Score por participante o agregado global? (Propuesta: agregado para tunear el
  prompt global; por-participante para alertas.)
- ¿El auto-tuner también debería tocar `MorningMessageGenerator`? (v1: no, sólo
  chat libre, que es donde están los anti-patrones.)
- ¿Tabla `prompt_tuning_runs` dedicada vs reusar `prompt_analyses`? (Propuesta:
  tabla dedicada por la serie temporal de scores + estado canary/rollback.)
- ¿Validación anti-PII con regex basta o se reusa el scrubber de Sentry? (Reusar
  patrón existente.)
