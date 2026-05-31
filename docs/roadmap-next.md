# Roadmap — próximos pasos (handoff)

> Documento de continuidad. La conversación que entregó las Fases 0–3 quedó sin contexto.
> Esto resume **qué se hizo**, **el estado actual** y **los pasos detallados** para lo que falta.
> Léelo junto a `CLAUDE.md`, `docs/business-rules.md` y `docs/decisions.md`.

_Última actualización: 2026-05-30 (sesión 2)._

---

## 0. Entregado en la sesión 2 (2026-05-30)

Rama `feat/roadmap-batch-pnl-payments-subscriptions`. 40 archivos (17 mod, 23 nuevos). Suite 362 ej / 0 fallos; rubocop 0; brakeman 0 nuevos.

- ✅ **Alta gateada por pago (individuos)** — estado `awaiting_payment`, `Participants::Activator` (ruta única de activación idempotente), `Participant#payment_required?`, `home#enroll → /pagos → commit activa`. Miembros cubiertos por empresa se activan directo. (business-rules §21)
- ✅ **P&L consolidado CLP/USD** — `/admin/resultado`, `Finances::CostCalculator` (fuente única de costos USD, compartida con Finanzas), Setting `usd_clp_rate`. Margen = ingreso recibido (CLP) − costos (USD→CLP). (business-rules §23)
- ✅ **Suscripciones recurrentes (Webpay Oneclick)** — `Subscription` + `Webpay::OneclickClient` + `/suscripcion` + `SubscriptionBillingJob` (cron diario + dunning→`past_due`) + `/admin/subscriptions` (MRR). ⚠️ **Kill-switch `webpay_oneclick_enabled` OFF hasta tener credenciales productivas Transbank Oneclick y verificarlas end-to-end.** (business-rules §22)
- ✅ **Caps de uso ya estaban enforced** — corregido "Known gaps" obsoleto en CLAUDE.md (`max_free_messages_per_day` + `inactivity_pause_days` ya funcionaban). 
- ✅ **Monitoreo de capacidad (3.1)** — `/admin/health` (`Ops::CapacitySnapshot`: colas Sidekiq, pool AR, memoria Redis, degrada si Redis cae) + `CapacityAlertJob` (cron 15 min → Sentry) + umbrales Setting `capacity_*`. (business-rules §24)
- ⏭️ **Visor de conversaciones tiempo-real (3.4) — diferido.** El layout admin no carga JS (Turbo/ActionCable no cableados en cliente; `cable.js` roto). Requiere pipeline de assets + verificación en navegador. Ver decisions.md.

Pendiente de despliegue: `kamal app exec 'bin/rails db:migrate'` (tabla `subscriptions` + `payments.subscription_id`). Setear `usd_clp_rate`. Para suscripciones en prod: setear `WEBPAY_ONECLICK_*`, `subscription_price_clp`, flip `webpay_oneclick_enabled=true`. Capacidad: ajustar `capacity_queue_latency_alert_seconds` / `capacity_backlog_alert_threshold` si los defaults (120s / 1000) no aplican.

---

## 1. Estado actual (lo ya entregado)

Rama mergeada a `main` y pusheada. 4 commits:

| Commit | Contenido |
|--------|-----------|
| `4c47da2` | **Fase 0** (caps de mensajes, auto-pausa, `coach_name`, Sentry+scrub PII) + **Fase 1** (modelo `Company`, multi-tenant) |
| `7382c31` | **Fase 2** — pagos Webpay Plus + ingresos/comisión/IVA |
| `4335fda` | **Fase 3** — portal participante passwordless + PWA |
| `648f6d2` | WIP pre-existente + fix de seguridad en `.gitignore` |

- **Tests**: 322 examples, 0 failures, 1 pending (Timecop, pre-existente). `asdf exec bundle exec rspec`.
- **Seguridad**: brakeman 0 warnings nuevos (3 pre-existentes/falsos positivos: pg_dump array-exec, mass-assign `:status` admin-gated, SVG estático).
- Reglas nuevas documentadas en `business-rules.md` §16–§20 y decisiones en `decisions.md` (entradas 30-may-2026).

### Deltas de arquitectura de esta sesión
- `Outbound::Dispatcher` + `ResponseMode` ya eran el switch IA on/off (no se tocó la lógica).
- `Company` **shadowea** la columna string `company` en `Participant`. Leer legacy con `participant[:company]`, asociación con `participant.company`. `company_id` es la fuente nueva.
- `Openai::ProgramManifesto.call(program, coach_name:)` inyecta coach global o por empresa en los 4 generadores.
- Pagos: `Payment` + `Webpay::Client` (SDK `transbank-sdk`, kill-switch `webpay_enabled`, `webpay_environment`). Flujo público `/pagos` + `/pagos/retorno` (idempotente). Admin ingresos en `/admin/payments`. Concern `PeriodFilterable` compartido con Finanzas.
- Portal: magic-link (`Participant.generates_token_for :portal_login`), `current_participant` en `ApplicationController`, `/portal` read-only, layout PWA.
- Observabilidad: `config/initializers/sentry.rb` (inerte sin `SENTRY_DSN`), scrubber `ImpulsoSentryScrub`.

---

## 2. Checklist de despliegue (hacer antes/durante el próximo deploy)

1. **Migraciones en prod**: `kamal app exec 'bin/rails db:migrate'` (companies, company_id refs, payments).
2. **Sentry**: crear proyecto en sentry.io → poner `SENTRY_DSN` en `.kamal/secrets` → configurar alertas (issue first seen / frecuencia → email/Slack).
3. **Webpay**: mantener `Setting webpay_environment=integration` hasta tener credenciales productivas; setear `WEBPAY_COMMERCE_CODE` / `WEBPAY_API_KEY` en `.kamal/secrets`; setear `Setting membership_price_clp`; flip `Setting webpay_enabled=true`.
4. **Coach**: setear `Setting coach_name` (global) y/o `Company#coach_name` por empresa.
5. **Identidad git**: `git config user.name/user.email` (los commits salieron con identidad auto del host).
6. `.kamal/secrets` y `node_modules` ahora están en `.gitignore` (estaban expuestos — corregido en `648f6d2`).

---

## 3. Backlog restante (de los 24 pedidos originales) — con pasos

### 3.1 Monitoreo de capacidad del servidor  ✅ ENTREGADO (sesión 3, ver §0)
Objetivo: saber cuándo el servidor está al límite (no solo errores, que ya cubre Sentry).
> Hecho: `Ops::CapacitySnapshot` + `Admin::HealthController` (`/admin/health`) + `CapacityAlertJob` (cron 15 min) + Settings `capacity_*`. Métricas de host (node_exporter) siguen diferidas (paso 3 abajo).
Pasos:
1. `Admin::HealthController#show` (o tab en dashboard): leer `Sidekiq::Stats.new` (enqueued, retry_size, dead_size), `Sidekiq::Queue.new(q).latency` por cola, pool de AR (`ActiveRecord::Base.connection_pool.stat`), Redis `INFO memory`.
2. `CapacityAlertJob` (cron cada 10–15 min en `schedule.yml`): si `queue.latency > N` o backlog > M, `Sentry.capture_message("Sidekiq backlog…", level: :warning)`.
3. Métricas de host (CPU/RAM/disco): vía `kamal app exec`/accessory; opcional `node_exporter` + alerta. Para 1 host basta umbral de latencia de cola + uso de memoria del proceso.
4. Tests del job (umbral dispara/no dispara) con Sidekiq stub.
Archivos: `app/jobs/capacity_alert_job.rb`, `app/controllers/admin/health_controller.rb`, vista, `config/schedule.yml`, nav.

### 3.2 Rediseño de landing (estilo YC) + design system
Pasos:
1. Auditar `app/views/home/index.html.erb` + `app/assets/stylesheets/landing.css`.
2. Definir **design tokens** (CSS vars: color, espaciado, tipografía, radios, sombras) — reutilizar/extender los de `admin.css`. Crear `app/assets/stylesheets/tokens.css`.
3. Secciones: hero (promesa + CTA), prueba social, cómo funciona (3 pasos), resultados, precios (ligado a `membership_price_clp`), FAQ, CTA final. Partials en `app/views/home/_*.html.erb`.
4. Responsive mobile-first; usar la skill `design`/`design-system` para crítica.
5. Añadir link "Ya soy participante → `/portal/acceso`" en nav/footer (discoverability, hoy falta).
6. Referencias: Linear, Vanta, Cal.com, Ramp (landings YC actuales).

### 3.3 Rediseño de reportes para que entreguen valor
Pasos:
1. Definir "valor": participante (narrativa de progreso, patrones, micro-logros), empresa (adherencia agregada y barreras, **anónimo**).
2. Síntesis semanal + de cierre (no solo diaria). Posible `Openai::WeeklySynthesizer` reutilizando patrón de `CheckinSummarizer`.
3. Rediseñar `app/views/admin/daily_reports/show` + vista en portal participante. Ligar a `MethodologyInsight` para agregados de empresa.
4. Para empresa: vista por `Company` con métricas anónimas (ya hay base en `methodology/insight_builder.rb`).

### 3.4 Visor de conversaciones en tiempo real  ⏭️ DIFERIDO (sesión 3)
> **Bloqueador descubierto:** el layout admin (`app/views/layouts/admin.html.erb`) **no carga JavaScript** — solo `stylesheet_link_tag`; el JS del panel es inline vanilla (drawer de ayuda). Además `app/javascript/cable.js` tiene error de sintaxis (`export consumer =`), señal de que el cliente ActionCable nunca se cableó. Habilitar streams exige: cargar bundle JS en admin + importar turbo/actioncable + arreglar `cable.js` + rebuild de assets + **verificación en navegador** (no confiable headless). Server-side (broadcast desde el modelo) es trivial; el cliente es el trabajo real. Retomar cuando se pueda verificar en navegador.

ActionCable + turbo-rails ya están (gemas). Pasos (cuando se retome):
0. **Cablear JS en admin**: `javascript_include_tag`/import de `@hotwired/turbo-rails` en el layout admin; arreglar `cable.js`; rebuild esbuild.
1. `Conversation` → `after_create_commit { broadcast_append_to "participant_#{participant_id}_convo", target: "messages", partial: ... }`.
2. En `admin/conversations/show`: `<%= turbo_stream_from "participant_#{@participant.id}_convo" %>` + contenedor `#messages`.
3. Verificar `config/cable.yml` (Redis en prod) y que el worker no rompa.
4. Test: crear Conversation → assert broadcast (`have_broadcasted_to`).

### 3.5 Sesiones 1-1 con coach
Pasos:
1. Migración + modelo `CoachSession` (UUID): `participant_id`, `admin_user_id` (coach), `scheduled_at`, `status` (requested/confirmed/done/cancelled), `meeting_url`, `notes`.
2. Admin CRUD bajo `namespace :admin`; vista en `Company`/`Participant` show.
3. Portal: ver próxima sesión + (opcional) solicitar.
4. Recordatorios: `CoachSessionReminderJob` (WhatsApp vía `Outbound::Dispatcher` / email). Idempotencia como los demás jobs.
5. Opcional: integración calendario (link Google/Cal.com) — empezar con `meeting_url` manual.

### 3.6 Skill "IA arregla errores"
Pasos:
1. Skill en plugin/`.claude/skills` que: lee issues de Sentry (Sentry MCP o API) → localiza stacktrace → reproduce → parche → corre `rspec`/`rubocop` → abre PR.
2. Requiere `SENTRY_DSN` + token API Sentry. Definir trigger ("arregla el último error de Sentry").
3. Reusar quality gate del repo (CLAUDE.md §Quality gate).

### 3.7 Research de mercado/coaches (tendencias, qué vende)
Tarea de investigación (skill `deep-research` / web). Entregable: brief con programas que venden, pricing, posicionamiento, ángulos. Sin código.

### 3.8 Personalización profunda por participante
Pasos:
1. Aprovechar `initial_pattern` + `energy_map` + reportes para adaptar tono/foco diario (ya hay contexto en system prompts).
2. Posible dificultad/branching adaptativo por fase. Evaluar `ParticipantProfile` si crece.
3. Cuidar prompt-caching (mantener prefijo estable; lo variable al final del prompt).

---

## 4. Follow-ups / deuda técnica

- ~~**Alta gateada por pago**~~ ✅ Entregado sesión 2 (§0).
- ~~**Suscripciones recurrentes**~~ ✅ Entregado sesión 2 (§0) — build completo, kill-switch OFF pendiente credenciales Oneclick prod.
- ~~**P&L consolidado CLP/USD**~~ ✅ Entregado sesión 2 (§0) — pendiente solo auto-fetch del tipo de cambio (hoy `usd_clp_rate` manual).
- **Verificar campos del SDK Oneclick contra integración real** cuando lleguen credenciales: nombres de respuesta (`tbk_user`, `details[].response_code`, `card_number_4_last_digits`) cubiertos por specs con dobles; confirmar con una corrida real antes de flip del kill-switch.
- **Edición de perfil en portal**: hoy read-only (consciente). Si se habilita, **bloquear** edición de membresía/datos para miembros de empresa (`pays_individually?` / `company_id`).
- **Migrar string `company` legacy → `Company`**: UI admin para mapear participantes viejos (string `participant[:company]`) a un `Company` y limpiar la columna.
- **Onboarding nativo del participante** (web/WhatsApp): hoy hay `SendWelcomeJob`/`SendWelcomeQuestionJob` (WhatsApp) y portal sin flujo guiado.
- **Push notifications PWA**: manifest listo, falta service worker push + suscripción.
- **`CLAUDE.md`/`AGENTS.md` están gitignored** en este repo: mantener ambos en sync localmente (el hook pre-push exige modelos/servicios documentados en `AGENTS.md`).

---

## 5. Comandos útiles

```bash
# Toolchain SIEMPRE con asdf
asdf exec bundle exec rspec
asdf exec bundle exec rubocop -A <archivos>
asdf exec bundle exec brakeman -q

# Hook pre-push exige AGENTS.md documente cada modelo/servicio nuevo.
# Deploy
kamal deploy
kamal app exec 'bin/rails db:migrate'
kamal app logs -f
```

## 6. Cómo arrancar la próxima conversación
Pega esto: _"Lee `docs/roadmap-next.md`. Continuemos con [ítem 3.1 / 3.2 / …]. Respeta el quality gate de CLAUDE.md (rubocop+rspec+brakeman, asdf, `.kept`, idempotencia, docs)."_
