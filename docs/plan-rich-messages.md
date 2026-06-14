# Plan de implementación — Mensajes enriquecidos (links y recursos)

> Estado: **propuesta**. No implementado. Kill-switches OFF por defecto.
> Alcance: enriquecer la **salida** de la app (hoy solo texto + templates) con
> (A) preview de links y (B) catálogo curado de recursos (links a videos/fuentes)
> que la IA selecciona por ID. **Sin upload.**

## 0. Principios de diseño (no negociables)

1. **La IA nunca escribe URLs en texto libre.** Solo selecciona recursos del
   catálogo por `id`/`slug`. Validación dura rechaza cualquier URL en el body que
   no provenga del catálogo. (Mismo patrón que `Openai::SkillCatalog` →
   `Openai::SkillTagger`: catálogo como prefijo estable para prompt caching, la IA
   devuelve identificadores, no contenido.)
2. **El descubrimiento de URLs reales requiere web search** (`gpt-4o-search-preview`
   / Responses API). La memoria paramétrica del modelo aluciona URLs — ningún
   modelo lo evita. El catálogo es la capa de reuso y seguridad-al-enviar, no la de
   hallazgo.
3. **Verificar ≠ HTTP 200.** Un recurso es válido solo si: (a) responde 2xx,
   (b) su contenido corresponde al tema declarado (LLM-juez), y (c) sigue vivo en
   el tiempo (re-validación periódica contra link rot).
4. **Nada enviable sin revisión humana** mientras el verifier no demuestre
   precisión. Reusa el patrón `program_intake_review_required` /
   `/admin/pending_responses`: candidato verificado → cola de revisión → admin
   aprueba → entra al catálogo enviable.
5. **Sin upload por-mensaje.** Links = URLs públicas ya existentes en internet.
   Audios = biblioteca pre-cargada una vez con URL pública (no se graba/sube por
   cada envío). WhatsApp exige `media_id` (upload) o `link` (URL público); usamos
   `link`.

---

## Feature A — Link preview en texto

**Esfuerzo: trivial. Es la base para B y C.**

### Backend
- `Whatsapp::Client#send_text` hoy fuerza `preview_url: false`. Hacerlo
  parametrizable: `send_text(to:, body:, preview_url: false)`.
- `Outbound::Dispatcher#send_text` y `#deliver_text` propagan `preview_url:`.
  Default sigue `false` (no cambia comportamiento actual).
- Setting nuevo `link_preview_enabled` (`type: :boolean, category: "program",
  default: false`). Cuando un mensaje contiene un link del catálogo, el dispatcher
  pasa `preview_url: true` solo si el setting está ON.

### Frontend
- Nada nuevo. El preview lo renderiza WhatsApp en el cliente del participante.
- Toggle en `/admin/settings` (ya existe la UI genérica de settings por categoría).

### Tests
- `spec/services/whatsapp/client_spec.rb`: `preview_url` se serializa correcto en el payload.
- `spec/services/outbound/dispatcher_spec.rb`: propagación del flag.

---

## Feature B — Catálogo de recursos (links a videos / fuentes)

### B.1 Modelo de datos

**Migración** (`db-migration` skill: UUID PK, JSONB defaults, soft-delete, índices).

```
create_table :resources, id: :uuid do |t|
  t.string  :title,            null: false
  t.text    :url,              null: false
  t.string  :kind,             null: false   # video | article | audio_ref
  t.string  :status,           null: false, default: "pending"
                                              # pending | verified | approved | rejected | dead
  t.string  :source,           null: false, default: "manual"
                                              # manual | program_seed | gap_detection
  t.text     :description
  t.jsonb    :topics,          null: false, default: []   # tags para selección IA
  t.uuid     :program_id                       # nil = general; set = scoped al programa
  t.datetime :last_verified_at
  t.jsonb    :verification,    null: false, default: {}   # {http_status, content_match, judge_reason}
  t.datetime :discarded_at
  t.timestamps
end
add_index :resources, :status
add_index :resources, :program_id
add_index :resources, :discarded_at
add_index :resources, "lower(url)", unique: true   # dedupe por URL
add_index :resources, :topics, using: :gin
```

**Modelo `Resource`** (`rails-conventions`):
- `include Discard::Model`; scope `.kept` por convención.
- Enums string: `kind`, `status`, `source`.
- Scopes: `.sendable` (`status: approved`, `kept`, `last_verified_at` reciente),
  `.for_program(program)` (general OR scoped), `.stale` (verificado hace > N días).
- `belongs_to :program, optional: true`.

**`ResourceDelivery`** (auditoría de qué recurso se mandó a quién — opcional pero
recomendado para medir utilidad y no repetir):
```
create_table :resource_deliveries, id: :uuid do |t|
  t.references :resource, type: :uuid, null: false, foreign_key: true
  t.references :participant, type: :uuid, null: false, foreign_key: true
  t.references :conversation, type: :uuid, foreign_key: true
  t.string :moment
  t.timestamps
end
add_index :resource_deliveries, [:participant_id, :resource_id]
```

### B.2 Descubrimiento — `Resources::Finder` (web search)

`app/services/resources/finder.rb`. Única fuente legítima de URLs.

- Input: `topic` (string) + `kind` (`video`/`article`).
- Llama OpenAI con web search (`gpt-4o-search-preview` vía `Openai::Client`; añadir
  soporte de modelo search en `Openai::ModelRouter` y un `task: :resource_finder`).
- Devuelve candidatos `{title, url, snippet}` **extraídos de los resultados de
  búsqueda reales**, nunca inventados por el modelo.
- Crea `Resource` con `status: pending`, `source: program_seed|gap_detection`.

> Nota: `gpt-4o-search-preview` se invoca por chat completions con ese modelo; la
> respuesta incluye `annotations`/`url_citation`. Validar que cada URL provenga de
> esas citaciones, no del texto generado.

### B.3 Verificación — `Resources::Verifier`

`app/services/resources/verifier.rb`. El 80% del valor está aquí.

1. **Existe**: `Net::HTTP` HEAD/GET, seguir redirects, exigir 2xx.
   (WebMock bloquea HTTP externo en tests → stub. Permitir solo http/https,
   bloquear IPs privadas/localhost → defensa SSRF.)
2. **Contenido correcto**: fetch del `<title>`/meta description (o transcript de
   YouTube si `kind: video`), pasar a un LLM-juez: "¿esta página trata sobre
   `topic`? ¿es apropiada para un participante de coaching?" → `{match: bool, reason}`.
3. **Persistir** `verification` jsonb + `last_verified_at`; `status: verified` si
   pasa, `rejected` si no.
- Registrar la llamada LLM vía `Openai::PromptLogger` (consistencia de costos).

### B.4 Selección por la IA — `Resources::Catalog` + integración en generadores

- `Resources::Catalog` (espeja `Openai::SkillCatalog`): construye bloque estable
  `- <id>: <title> — temas: <topics>` de `Resource.sendable.for_program(...)`.
  Prefijo de sistema → prompt caching.
- Integrar en `Openai::FreeResponseGenerator` y `Openai::MorningMessageGenerator`:
  - Inyectar catálogo; pedir al modelo que, si un recurso aplica, devuelva su `id`
    en un campo JSON aparte (`{"body": "...", "resource_id": "..."}`) **o** vía
    tool-calling `attach_resource(id)`. **El body nunca contiene la URL.**
  - El dispatcher arma el mensaje final: `body` + (si hay `resource_id` válido y
    `sendable`) anexa la URL del catálogo + `preview_url: true`.
- **Validación anti-alucinación**: regex que detecte cualquier URL en `body`; si
  aparece y no corresponde a un recurso `sendable`, se descarta el envío del link
  (o se loguea y manda solo texto). Gate por `resource_catalog_enabled`.

### B.5 Seed al generar programa

- En `ProgramGenerationJob` (tras `Programs::Builder`), encolar
  `SeedProgramResourcesJob(program_id, topics)`:
  - `ProgramGenerator` ya produce el spec; extender su salida JSON con
    `resource_topics: [...]` (temas, **no** URLs).
  - El job corre `Finder` por cada tema → `Verifier` → deja `status: verified`
    para revisión humana (no `approved` aún).

### B.6 Crecimiento por análisis de conversación

- `ResourceGapDetector` (espeja `Openai::SkillTagger`): tras check-in/chat libre,
  analiza si haría falta un recurso sobre tema X.
- Encolar desde `TagConversationSkillsJob` (ya corre en ese punto) o un job hermano
  `DetectResourceGapJob`. Gated por `resource_autodiscovery_enabled` (**OFF** por
  defecto — es lo más arriesgado).
- Gap detectado → `Finder` → `Verifier` → cola de revisión.

### B.7 Re-validación periódica (link rot)

- `RevalidateResourcesJob` (cron diario, fan-out tipo `MorningWakeJob`):
  toma `Resource.stale`, re-corre `Verifier`, marca `status: dead` y `discard` los
  muertos. Entrada en `config/schedule.yml`.

### B.8 Frontend (admin) — `/admin/resources`

Controllers/views nativos Rails bajo `namespace :admin` (patrón `skills_controller`).

- **`Admin::ResourcesController`**
  - `index`: tabla filtrable por `status`/`kind`/`program`/`topic` + búsqueda
    (copiar el patrón de búsqueda de `SkillsController#index`). Badges de estado.
    Contadores (total, pendientes de revisión, muertos).
  - `show`: detalle del recurso + `verification` jsonb + historial de
    `ResourceDelivery` (a quién se mandó).
  - `new`/`create`: alta **manual** (coach pega URL verificada a mano → corre
    `Verifier` síncrono y guarda).
  - `edit`/`update`: editar título/temas/programa.
  - `approve`/`reject` (member routes, `PATCH`): mover `verified → approved/rejected`.
    Es el gate de revisión humana. Botón "Verificar de nuevo" → `Verifier`.
  - `destroy`: `discard`.
- **Cola de revisión**: scope `index?status=verified` como vista principal de
  trabajo (no hace falta controller separado; basta el filtro default).
- **Vistas**: `app/views/admin/resources/{index,show,new,edit,_form}.html.erb`,
  tokens de `admin.css`.
- **Nav**: enlace en el layout admin junto a "Habilidades".

### B.9 Settings nuevos (`app/models/setting.rb`)

| key | type | default | categoría | propósito |
|-----|------|---------|-----------|-----------|
| `resource_catalog_enabled` | boolean | `false` | program | Kill-switch: la IA puede anexar recursos del catálogo a mensajes generativos |
| `resource_autodiscovery_enabled` | boolean | `false` | openai | Kill-switch: detección de gaps + web search automático tras conversaciones |
| `resource_review_required` | boolean | `true` | program | Candidatos quedan `verified` pendientes de aprobación humana antes de ser enviables |
| `resource_revalidation_days` | integer | `30` | program | Antigüedad tras la cual un recurso se considera `stale` y se re-valida |
| `resource_finder_max_candidates` | integer | `5` | openai | Candidatos por búsqueda |
| `openai_max_tokens_resource_finder` | integer | `1500` | openai | max_tokens del Finder |
| `link_preview_enabled` | boolean | `false` | program | Renderiza preview de link en WhatsApp (Feature A) |

### B.10 Tests (`testing` skill)
- Model: scopes (`sendable`, `stale`, `for_program`), dedupe único por URL, discard.
- `Finder`: stub OpenAI search response, asserta que solo persiste URLs de citaciones.
- `Verifier`: WebMock stub 2xx/404/redirect/SSRF-block; LLM-juez stubbeado.
- `Catalog`: bloque estable, solo `sendable`.
- Generadores: validación anti-alucinación (URL en body sin recurso → no se envía).
- Jobs: `SeedProgramResourcesJob`, `RevalidateResourcesJob` (idempotencia, dead-marking),
  `DetectResourceGapJob` (gated).
- Request specs admin: approve/reject, verify-again, búsqueda/filtro.

---

## Orden de implementación recomendado

1. **Feature A** (link preview) — base, trivial, sin riesgo.
2. **Feature B core, modo curación manual**: modelo `Resource`, `Verifier`,
   `/admin/resources` (alta manual + approve), `Catalog` + integración en
   generadores con validación anti-alucinación. **Autodiscovery OFF.**
   → Permite empezar a enviar recursos curados a mano con seguridad total.
3. **Feature B descubrimiento**: `Finder` (web search) + seed al generar programa.
   Medir precisión del `Verifier` con candidatos reales antes de aflojar el gate.
4. **Feature B autodiscovery**: `ResourceGapDetector` + cron de re-validación.
   Encender `resource_autodiscovery_enabled` solo si el verifier acierta > ~90%.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| IA aluciona URLs | IA solo devuelve IDs; validación regex anti-URL en body; web search con citaciones como única fuente |
| Link rot (recurso muere) | `RevalidateResourcesJob` cron + `last_verified_at` + `status: dead` |
| Contenido inapropiado a participante | LLM-juez en `Verifier` + revisión humana obligatoria (`resource_review_required`) |
| SSRF en el Verifier | Allowlist http/https, bloqueo de IPs privadas/localhost, timeout corto |
| Costo web search | Cap `resource_finder_max_candidates`; autodiscovery OFF por defecto; cachear catálogo (prompt caching) |

## Documentación a actualizar al implementar (`documentation` skill)
- `docs/business-rules.md` → nueva sección **§30 Recursos y mensajes enriquecidos**.
- `docs/decisions.md` → decisión "IA selecciona recursos por ID, nunca escribe URLs".
- `CLAUDE.md` → service objects (`Resources::*`), jobs nuevos, settings, "Known gaps".
- `.env.example` → si web search requiere credenciales.
