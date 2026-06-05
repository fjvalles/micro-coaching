# Decisiones Autónomas — Impulso

Decisiones que tomé durante la implementación, separadas de lo que el plan ya dictaba.

## Entorno

- **Ruby 4.0.2 en vez de 3.3.x.** Solo había 4.0.2 instalado vía asdf. Rails 7.2 funciona
  con Ruby 4.x; no se justifica perder tiempo instalando 3.3 si todo arranca. Si en
  producción hay que volver a 3.3, basta con cambiar `.tool-versions` y `bundle install`.
- **Postgres 16 y Redis 7 vía Homebrew**, no Docker. El plan menciona Docker como opción
  pero también acepta Homebrew. Más rápido para arrancar localmente; ya quedaron como
  servicios `brew services`.
- **Sin `docker-compose.yml`.** Como uso servicios Homebrew, no añadí el compose. Si se
  necesita en otra máquina, se crea en 1 minuto con Postgres + Redis.

## Esquema y modelos

- **UUID en todas las tablas** (incluido `admin_users`). Plan lo pedía; lo apliqué desde
  la migración inicial (`enable_extension :pgcrypto`).
- **`AdminUser` con Devise modules: `database_authenticatable, recoverable, rememberable,
  lockable, validatable`.** Quité `registerable` (no debe haber auto-registro de admin) y
  añadí `lockable` por el plan.
- **`Participant#pending_checkin_at` añadido al esquema** (no estaba explícito en la
  tabla del plan, pero `MessageClassifier` lo necesita para detectar la ventana de
  check-in).
- **`energy_map` con default `{}`** para evitar `nil.dig` en los generadores.

## WhatsApp

- **`Whatsapp::Client` con `Net::HTTP` puro**, no `httparty`/`faraday`. Es una sola
  llamada POST con retries; meter una gem adicional no aporta nada y `Net::HTTP` ya está
  en stdlib.
- **Decisión del plan #1 (open question) confirmada**: el `morning_template` se trata
  como prompt-base para OpenAI, y Meta sólo aprueba plantillas genéricas con `{{1}}` y
  `{{2}}`. Así se cubren los 14 días con 4 templates (bienvenida, despertar, IAReto,
  check-in) en vez de 28+.
- **Decisión del plan #2 confirmada**: IAReto sale como segundo mensaje 30 min después
  del despertar (`SendIaretoJob` con `wait: 30.minutes`). Si el participante respondió
  en ese rato, va como texto libre (gratis); si no, como template.
- **Decisión del plan #3 confirmada**: no hay flujo de re-engagement si el participante
  se calla 3+ días. El día se queda hasta que llegue un check-in.
- **Plantilla de "checkin"** (`checkin_dia_NN`) añadida implícitamente en
  `CheckinForParticipantJob`. El plan menciona "3 questions en un template" — el código
  lo soporta vía 4 variables.

## OpenAI

- **`gpt-4.1-mini`** como en el plan, con `temperature: 0.75` para morning/free y `0.3`
  para `CheckinSummarizer` (necesita JSON estable).
- **`response_format: { type: "json_object" }`** en el summarizer + fallback a texto raw
  si `JSON.parse` falla. El plan lo pedía.
- **`PROGRAM_MANIFESTO` como constante compartida** (`app/services/openai/program_manifesto.rb`).
  Va al inicio de todos los system prompts para maximizar prompt caching (OpenAI cachea
  ≥1024 tokens reutilizados en ~5 min).

## Jobs

- **Separación `MorningWakeJob` (filtra) → `MorningWakeForParticipantJob` (envía)** como
  pide el plan. Idem para checkin.
- **`GenerateAndSendManifestoJob` añadido** (no aparece por nombre en el plan, pero
  `AdvanceDayJob` lo necesita en el día 15 y es más limpio que inlinearlo).
- **Idempotencia por scope `Conversation.where(moment: ..., day_number: ...)`** en
  morning/checkin/iareto. Si un job corre dos veces el mismo día, no duplica.

## Panel de Administración (Nativo)

- **Panel admin nativo desde el inicio:** Se evaluó Avo Community y se descartó por límites de licencia (sin dashboards ni acciones custom sin pagar Pro). El panel se construyó directamente con controladores y vistas Rails bajo `namespace :admin`. Nota histórica únicamente — Avo no está instalado.
- **Aesthetics & Design System:** Diseñado desde cero bajo principios modernos de UI/UX (Kole Jain style), con barra lateral persistente, animaciones sutiles, estados vacíos estilizados, y un tema oscuro/claro balanceado usando variables CSS nativas (`admin.css`).
- **Dashboard de Métricas:** Se implementó un dashboard nativo con 4 tarjetas de métricas (Participantes Activos, Pendientes, Mensajes de Hoy, Errores de Envío) y paneles de actividad reciente en tiempo real.
- **Acciones Personalizadas Nativas:** Las acciones de "Inscribir Participante" (que dispara `SendWelcomeJob`), archivar (soft-delete vía `discard`), y desarchivar se implementaron mediante controladores y rutas estándar de Rails.
- **Chat e Historial Visual:** La vista del participante incluye una renderización en burbujas de conversación estilo WhatsApp con información de tokens y logs de OpenAI.
- **Integración de Docs:** El controlador `Admin::DocsController` se adaptó para heredar de `Admin::BaseController`, compartiendo la navegación y la hoja de estilos unificada.

## Tests

- **60 ejemplos, 0 fallos, 2 pending.** Los 2 pending son tests que dependen de Timecop
  (no instalado intencionalmente; uso `travel_to` de Rails en su lugar y los reescribí).
- **VCR cassette dir creado** (`spec/vcr_cassettes/`), pero los generadores de OpenAI
  los stubeo con `allow_any_instance_of(...).to receive(:call)` para no depender de
  cassettes en CI. Cuando se quiera grabar tráfico real, basta con `VCR.use_cassette`.
- **WebMock bloquea net externo** y permite localhost (para Rails server en specs).

## Seguridad

- **`devise_for :admin_users` declarado antes del `namespace :admin`** en `routes.rb`; todo el namespace (y `Sidekiq::Web`) vive dentro de un bloque `authenticate :admin_user do … end` para que Devise pueda exigir login.
- **`Whatsapp::SignatureVerifier`** usa `secure_compare` y rechaza si falta el secret.
- **Webhook devuelve 200 inmediatamente** y delega a Sidekiq, como exige Meta (5s timeout).

## Documentación

- **`DECISIONS.md` → `docs/decisions.md`.** Todo doc operativo vive en `docs/`. README + CLAUDE.md sólo en raíz porque las convenciones lo esperan ahí.
- **Página `/admin/docs`.** Operadora no-técnica necesita leer reglas/decisiones sin clonar el repo. Controller `Admin::DocsController` con whitelist (`DOCS` constant) renderiza Markdown vía `kramdown` + parser GFM. Sin path traversal: slug → ruta fija. Link en el sidebar nativo del panel admin.
- **`kramdown` no `commonmarker`.** `commonmarker` requiere compilar Rust → falla en Ruby 4.0.2 (`thiserror` + `time` crate no compilan). `kramdown` es pure-ruby, instala sin extensión nativa. Compromiso: render menos fiel a GFM en edge cases, suficiente para docs internas.
- **`bin/check-doc-refs`.** Las refs `path:line` en `business-rules.md` se rompen con cualquier refactor. Script valida existencia de archivo + rango de líneas. Correr antes de merge si tocaste algo referenciado.

## Landing Page Pública y Rediseño B2B

- **Integración directa en el monolito Rails.** Para evitar la complejidad de CORS, autenticaciones API y latencias de red, se construyó la página de aterrizaje directamente en el proyecto Rails enrutando la raíz a `HomeController#index`. Esto permite llamar directamente al servicio `Participants::Enroller` y generar demostraciones dinámicas usando `Openai::Client` en modo local.
- **Desarrollo sin Node.js (Vanilla CSS & JS).** Dado que la aplicación no cuenta con dependencias npm ni empaquetadores configurados (con un `package.json` vacío/inexistente), se optó por escribir una hoja de estilos Vanilla CSS (`landing.css`) y scripts Vanilla JS nativos en lugar de añadir frameworks o configurar compiladores pesados. Esto asegura que la página sea ligera (<150KB), óptima para móviles y de carga instantánea.
- **Automatización de Zona Horaria y Validación E.164.** Para cumplir con las reglas del negocio sobre el envío de mensajes a hora fija local, el formulario detecta automáticamente la zona horaria del navegador del usuario vía `Intl.DateTimeFormat`. El teléfono se normaliza automáticamente al formato internacional E.164 eliminando caracteres inválidos y asegurando el prefijo `+`.
- **Simulador Interactivo de WhatsApp en el Hero.** Para adaptarnos al reposicionamiento B2B de "Impulso by Comtraining", incorporamos un simulador interactivo de WhatsApp en Javascript en el Hero. Permite a los sponsors de las empresas seleccionar entre 4 problemáticas típicas de liderazgo (conversaciones difíciles, priorización, feedback, comunicación de cambios) y ver cómo el bot redacta y responde en tiempo real con retardos de escritura.
- **Captura y Almacenamiento de Datos Corporativos.** Añadimos las columnas `company` y `role` a la tabla `participants` mediante una migración de base de datos. De esta forma, el formulario de registro y el panel de administración ahora capturan la estructura corporativa del líder que se inscribe en el piloto para facilitar el embudo de ventas B2B.

## Estrategia Comercial

- **Reposicionamiento B2B como `Impulso by Comtraining`.** El producto deja de describirse primariamente como "hábitos por IA" y pasa a presentarse como una capa de transferencia conductual post-capacitación para liderazgo y gestión del cambio. La razón es comercial: reduce ambigüedad, aprovecha la credibilidad del coach experto y se alinea mejor con buyers tipo PMO, Transformación y RRHH.
- **Piloto fundacional antes que pricing agresivo.** Para validar dolor real, adherencia y relato comercial, se prioriza un piloto sin costo con cohorte acotada y sponsor comprometido. Si la conversión a pagado no aparece tras 1 a 3 pilotos, habrá que revisar posicionamiento, segmento o caso de uso antes de escalar.
- **Documentación comercial dentro del repo.** Se agregan Lean Canvas, DVF, entrevistas de descubrimiento, oferta estilo Hormozi y branding como documentación oficial del proyecto. La tesis es que este producto necesita acoplar decisión técnica y decisión comercial desde el comienzo; no sirve tener una app correcta sin una oferta comprable.
- **Seeds con portafolio inicial de programas.** Se reemplaza el seed único genérico por tres programas de 14 días listos para operar: liderazgo, cambio y productividad sostenible. La razón es que el producto ya se está posicionando comercialmente con esos casos de uso; si la base de datos no los soporta, la landing y el admin prometen más de lo que existe en contenido.

## Lo que queda fuera (consciente)

- Vista previa de prompts en UI (servicio `dry_run` ya listo).
- Templates Meta auto-submission (manual via dashboard de Meta).
- Pagos.
- Deployment (Kamal/Heroku/Render).

## Admin de Day Contents por programa

- **`DayContent` pasa a requerir `program_id` y el admin conserva contexto de programa.** La app ya validaba unicidad de `day_number` por `program_id`, los seeds crean contenido por programa y la ficha del programa ya era el lugar natural para operar sus días. Endurecer la relación evita contenidos huérfanos y hace consistente la navegación del panel.
- **La vista global de `Días y Contenidos` se conserva, pero como consola de auditoría con filtros.** En vez de eliminarla, se añadió filtrado por programa, día, fase, estado y texto libre sobre título/contenidos. Así los operadores pueden trabajar dentro de un programa sin perder una vista transversal cuando existan varios programas activos.

## Procesamiento de audio (transcripción + análisis paralingüístico)

- **Transcripción con `gpt-4o-mini-transcribe`, análisis con `gpt-4o-mini-audio-preview`.** El primero es notablemente más barato y rápido que `whisper-1` con calidad equivalente en español. Para el análisis se eligió el modelo multimodal "audio-preview" porque permite inferir tono, energía, ritmo, pausas, voz temblorosa — señales que se perderían si solo se infiriera tono a partir del texto transcrito. Ambos modelos se exponen como settings (`openai_transcription_model`, `openai_voice_analysis_model`) para poder rotar sin redeploy.
- **Dos kill-switches separados** (`audio_processing_enabled`, `openai_voice_analysis_enabled`). El primero corta el feature completo y vuelve al copy de rechazo. El segundo permite seguir transcribiendo (barato) cuando el análisis multimodal está degradado o sale caro. Granularidad útil para incidentes parciales del lado de OpenAI.
- **Conversión OGG→MP3 con ffmpeg.** WhatsApp envía notas de voz como `audio/ogg` (opus). `gpt-4o-audio-preview` solo acepta `wav` y `mp3`, así que se transcodifica con ffmpeg a mp3 16kHz mono 32kbps (suficiente para análisis de voz). Si `ffmpeg` no está instalado, el análisis se salta con `skipped_reason: "ffmpeg_unavailable"` y la transcripción sigue funcionando (Whisper sí acepta ogg). `Dockerfile` ahora incluye `ffmpeg` en el stage base.
- **Análisis se inyecta como "nota paralingüística" al prompt, no al body.** La transcripción literal queda intacta en `Conversation#body` y `#transcription`; las señales de voz se anexan únicamente en el mensaje que recibe el LLM generativo. Razón: preservar la trazabilidad de lo que la persona literalmente dijo, separado de inferencias del modelo. Persistido en `voice_analysis` jsonb para que el admin pueda auditarlo más tarde.
- **Límite duro de duración (`audio_max_duration_seconds`, default 180s).** Audios largos se transcriben (la transcripción se conserva como evidencia) pero el flujo de respuesta se corta con un copy pidiendo síntesis. Protege costo de tokens y calidad de respuesta: notas de voz de 8 minutos vuelven al LLM divagar.

## Backup diario a Google Drive

- **`pg_dump --format=custom` directo a archivo, no streaming.** Permite verificar tamaño antes de subir y reusar `upload_source` (file path) del SDK de Drive, que internamente hace upload resumable sin cargar todo a memoria. El archivo vive en `tmp/backups/` y se borra en el `ensure` del job sin importar si la subida falló — el dump no debe persistir local.
- **Service Account + scope `drive.file` (no `drive`).** `drive.file` solo otorga acceso a archivos creados por la app, principio de mínimo privilegio. Para que funcione, la carpeta destino debe estar compartida explícitamente con el email del service account (rol Editor). `GOOGLE_SERVICE_ACCOUNT_JSON` se pasa como string JSON completo en ENV — más fácil de inyectar en runtimes serverless que un path de archivo.
- **Retención por `createdTime` server-side, no por nombre del archivo.** Filtrar por createdTime evita depender del formato del filename y tolera relojes desincronizados localmente. Cutoff: 7 días. Se ejecuta dentro del mismo job después del upload exitoso, así un fallo de upload no borra el histórico.
- **Cron a las 03:00 UTC.** Lejos de `MorningWakeJob` (07:00 local de cada participante → entre 12:00 y 15:00 UTC) y de `AdvanceDayJob` (06:00 UTC). Reduce contención de DB durante el dump.
- **`pg_dump` debe existir en el ambiente de deploy.** Sin esto el job falla con `DumpError`. Cuando se configure deployment, asegurarse de que el cliente postgres esté instalado en la imagen.

## Registro y mejora de prompts IA (24-may-2026)

- **Tabla separada `prompt_executions` en vez de extender `conversations`.** El registro de prompts vive aparte porque (a) no toda ejecución produce Conversation (voice_analyzer, analysis), (b) la cardinalidad de re-ediciones de prompt es ortogonal al modelo de mensajería, (c) facilita ciclos de borrado independientes (executions se podan, conversations no).
- **Auto-captura del system prompt desde el código.** El primer call a un generador crea `PromptTemplate` con el system prompt actual como `current_body`. Pros: cero setup manual; contras: si el código cambia y nadie corrió el generador, el registro queda atrás. Aceptado — los crons diarios garantizan ejecución frecuente.
- **`day_system_prompt` vive como template per-día.** `DayContent.ai_system_prompt` se sincroniza vía `after_save` hook a `PromptTemplate(key: 'day_system_prompt', day_number: N)`. Esto permite versionar las ediciones de prompts diarios desde la UI existente sin duplicar formularios.
- **`PromptCritic` usa el mismo `Openai::Client` y devuelve JSON.** Se reutiliza la infra (retries, dry-run) en lugar de tocar la API directo. Modelo y temperatura por default; SAMPLE_SIZE=20 ejecuciones para evitar prompts gigantes.
- **Aplicar sugerencia = crear versión, no reemplazar.** El botón "Aplicar como nueva versión" en analyses encola el body sugerido como `PromptVersion` con origen `analysis` y lo promueve a current_body. La versión previa queda en historial y se puede revertir desde la UI (editar + pegar body anterior).

## Supervisión Humana y Modos de Respuesta (24-may-2026)

- **Modos `auto`, `approve`, `suggest` y `manual` con precedencia dinámica.** La precedencia `participante > programa > global Setting` permite aislar y auditar usuarios específicos o programas de prueba sin perturbar el resto de la base instalada.
- **Outbound Dispatcher como único punto de entrada.** Toda mensajería saliente generada por la aplicación pasa a través de `Outbound::Dispatcher`, el cual intercepta el envío y delega a la cola `PendingResponse` si el modo actual no es `auto`. Esto encapsula las reglas de despacho en un solo lugar y previene desbordamiento no deseado a WhatsApp.
- **Cola centralizada `PendingResponse` con notificaciones de correo.** Se optó por una sola tabla de respuestas pendientes en vez de flaguear `conversations`. Los administradores son notificados por correo SMTP (vía `Resend`) y gestionan la cola desde `/admin/pending_responses`.

## Sistema de Aprendizaje Continuo (24-may-2026)

- **Capa agregada pre-calculada en `MethodologyInsight`.** En lugar de hacer consultas SQL pesadas y llamadas síncronas a OpenAI al cargar `/admin/metodologia`, el job nocturno `RefreshMethodologyInsightsJob` materializa los resultados en el campo JSONB `payload` de la tabla `methodology_insights` con un start/end window. Esto optimiza el tiempo de respuesta del panel a <50ms.
- **Pattern clustering mediante LLM.** El análisis de patrones de check-in (`key_pattern_cluster`) se delega a `Openai::PatternClusterer` para agrupar dinámicamente las respuestas semanales y mensuales en temas comunes, mapeando su frecuencia y proporcionando enlaces drill-down a los reportes originales.

## Registro de Números Desconocidos (24-may-2026)

- **Tabla `unknown_inbounds` con índice único en `wamid`.** Al recibir webhooks de números no registrados, se registra el evento en `unknown_inbounds` y se ignora el mensaje de manera segura. Esto previene llamadas costosas accidentales y spam a la API de OpenAI, y el índice en `wamid` actúa como guardrail contra reintentos duplicados del webhook de Meta.

## Observabilidad, Límites de Uso y Coach Name (30-may-2026)

- **Sentry sobre New Relic para error tracking.** En un solo host Hetzner con Kamal, un APM completo (New Relic) es desproporcionado en costo/peso. Se eligió `sentry-ruby/-rails/-sidekiq` por su free tier generoso, alertas por email/Slack listas y tracking de releases. El initializer es **inerte sin `SENTRY_DSN`**, así dev/test/CI no se ven afectados.
- **Scrubbing de PII obligatorio (Ley 19.628).** La app maneja teléfonos y cuerpos de mensajes. `send_default_pii = false` + un `before_send` con scrubber recursivo (`ImpulsoSentryScrub`) que redacta teléfonos/emails y claves sensibles. Decisión consciente: preferimos perder algo de contexto de debugging antes que filtrar datos personales a un tercero.
- **Enforce de `max_free_messages_per_day` e `inactivity_pause_days`.** Estaban scaffolded en `Setting::SCHEMA` sin consumidores. Se implementaron: tope de mensajes libres en `ProcessIncomingMessageJob#free_cap_reached?` (control de costo runaway) y auto-pausa diaria con reactivación al primer inbound (`PauseInactiveParticipantsJob`). Ambos con `0 = desactivado` para no romper instalaciones existentes.
- **`coach_name` inyectado en un solo punto.** Se anexa en `Openai::ProgramManifesto.call` en vez de tocar los 4 generadores, manteniendo el prefijo de prompt-caching estable. El override por empresa se difiere al modelo `Company` (Fase 1).

## Modelo Company / Multi-tenant (30-may-2026)

- **`company` pasa de string a modelo `Company`.** Se agregó `companies` + `participants.company_id` + `programs.company_id`. Una migración de backfill no destructiva crea una `Company` por cada string distinto de `participants.company` y mapea `company_id`; la columna string legacy se conserva (deprecada) para reversibilidad y para el alta pública.
- **Colisión de nombres asumida conscientemente.** `belongs_to :company` sombrea la columna `company`. Se eligió que la asociación sea dueña del nombre (estado final correcto) y se migraron todos los usos del string en la UI (`participants` index/show, `pending_responses` show) a la asociación; `Participants::Enroller` escribe el string legacy vía `write_attribute`. El valor legacy se lee con `participant[:company]`.
- **Programas generales vs por empresa con un solo `company_id` nulable.** `nil` = general. Evita una tabla de membresía programa↔empresa para el caso actual (un programa pertenece a lo sumo a una empresa).
- **`covers_membership` en `Company`.** La regla "no paga si pertenece a empresa" se modela a nivel empresa (default cubre), con `Participant#pays_individually?` derivado. Prepara Fase 2 (pagos) sin tablas de billing todavía.

## Pagos con Webpay Plus (30-may-2026)

- **Transbank `transbank-sdk` sobre integración HTTP propia.** El SDK oficial maneja firma/endpoints/ambientes; reimplementarlo sería frágil. `Webpay::Client` lo envuelve con un `Result`/`CommitResult` struct, honra el kill-switch `webpay_enabled` y reporta errores a Sentry.
- **Un solo modelo `Payment` (pago único), no `Subscription` todavía.** El MVP cobra una membresía individual al inscribirse. Las suscripciones recurrentes (Oneclick/cuotas) se difieren hasta validar el modelo de cobro.
- **`commit` idempotente por `token`.** Webpay puede reenviar el retorno (refresh, doble redirect); si el `Payment` ya está `authorized`/`rejected` no se vuelve a confirmar. `TBK_TOKEN` se mapea a `aborted`.
- **Montos en CLP con IVA incluido; comisión congelada al confirmar.** `assign_commission_snapshot!` guarda comisión Transbank (+IVA) y neto recibido con las tasas vigentes al pago, para que cambios futuros de tasa no alteren el histórico. El IVA débito se desglosa on-the-fly del bruto.
- **Ingresos (CLP) separados de costos (USD).** No se mezclan monedas en un P&L combinado todavía; `/admin/payments` muestra ingresos, `/admin/finances` costos. Un consolidado con FX queda pendiente.
- **`PeriodFilterable` concern.** Se extrajo el filtro de períodos compartido entre `FinancesController` y `Admin::PaymentsController` (reuse, no duplicar).

## Portal del participante — auth passwordless (30-may-2026)

- **Magic-link en vez de un segundo Devise.** Los participantes se identifican por teléfono/email y no necesitan contraseña. Se usó `generates_token_for :portal_login` (firmado, expira 30 min, se invalida al cambiar el email) + `session` cifrada, evitando el peso/superficie de un segundo modelo Devise.
- **Defensa en profundidad.** Respuesta uniforme en la solicitud de link (anti-enumeración de emails), Rack-Attack por IP y por email (anti email-bombing), `reset_session` al iniciar sesión (anti session-fixation), y `current_participant` filtra por `.kept` (un participante archivado no puede entrar).
- **Portal read-only en v1.** Ver progreso/reportes + CTA de pago para individuos. No se edita perfil: satisface trivialmente "el miembro de empresa no modifica su membresía" y reduce superficie de ataque. La edición se difiere.
- **PWA reaprovechada.** El layout del portal enlaza el `manifest` existente para permitir instalar la cuenta como app; no se construyó un service worker nuevo.

## Alta gateada por pago + P&L consolidado + Suscripciones (30-may-2026)

- **`Participants::Activator` como ruta única de activación.** La lógica "activar (día 1) + `SendWelcomeJob`" estaba duplicada en `Enroller` y `Admin::ParticipantsController#enroll`. Se extrajo a un servicio idempotente reusado por enroll público, admin enroll, commit de pago y primer cobro de suscripción. Evita dobles bienvenidas y divergencia. Antes que pasar un flag por cada call site, el servicio detecta `active?` y hace no-op.
- **Estado `awaiting_payment` (enum 4) en vez de reusar `pending`.** `pending` ya tenía semántica difusa ("creado, rara vez usado"). Un estado explícito hace el gating legible y evita que el cron/broadcast toquen a quien no ha pagado. `Enroller` solo lo usa cuando `payment_required?`.
- **Gating solo para individuos que realmente pagan (`payment_required?`).** = `pays_individually?` + `membership_price_clp > 0` + `webpay_enabled`. Miembros cubiertos por empresa y entornos con pagos apagados se activan de inmediato — no se bloquea el alta por configuración faltante.
- **P&L: tipo de cambio manual (`usd_clp_rate` Setting), no auto-fetch.** Ingresos en CLP, costos en USD. Un Setting manual editable en `/admin/settings` evita una dependencia HTTP externa (y su mock en tests) para el MVP; auto-fetch desde mindicador.cl queda como mejora. Margen = ingreso recibido (neto de comisión) − costos convertidos.
- **`Finances::CostCalculator` como fuente única de costos USD.** Se extrajo el cálculo (precios OpenAI por modelo + prorrateo de fijos) que vivía inline en `FinancesController` a un servicio con `Result` struct, ahora consumido también por `ProfitLossController`. `OPENAI_PRICING` se movió ahí (la vista de Finanzas referencia la nueva constante). Reuse, no duplicar la matemática.
- **Suscripciones con Webpay Oneclick Mall, build completo pero kill-switch OFF.** Se implementó el modelo `Subscription`, `Webpay::OneclickClient` (inscripción + cobro), `SubscriptionsController`, `SubscriptionBillingJob` (cron diario con dunning) y `/admin/subscriptions`. `webpay_oneclick_enabled` queda **false** hasta tener credenciales productivas de Transbank Oneclick y verificarlas end-to-end; el SDK trae credenciales de integración para dev/test. Se construye ahora para no re-paginar contexto después.
- **Tokenización, nunca la tarjeta.** `Subscription` guarda solo `tbk_user`/`tbk_username` (token recurrente de Transbank). El cobro recurrente usa el token contra el commerce code hijo del Mall.
- **`Subscription.participant` nulable (como `Payment`).** El flujo público crea la suscripción antes de exigir `participant_id`; se siguió el patrón de `Payment` (FKs opcionales) en vez de forzar la asociación, para no romper el alta anónima ni los tests de flujo.
- **Idempotencia de cobro por `next_billing_at`.** `SubscriptionBillingJob` cobra `Subscription.billable` (active + vencidas); un cobro exitoso avanza la fecha (sale del scope), un fallo reprograma a mañana. Re-correr el job el mismo día no duplica cobros — mismo principio que la idempotencia por scope en los jobs de mensajería.
- **Nota de campos del SDK Oneclick.** Los nombres de campos de respuesta de Oneclick (`tbk_user`, `details[].response_code`, `card_number_4_last_digits`) siguen el SDK Ruby de Transbank y están cubiertos por specs con dobles; deben re-verificarse contra una corrida real de integración cuando lleguen las credenciales (el kill-switch lo cubre mientras tanto).

## Monitoreo de capacidad (31-may-2026)

- **`Ops::CapacitySnapshot` como única fuente de métricas de capacidad.** Lee Sidekiq (`sidekiq/api`), pool AR y Redis. Compartido por `Admin::HealthController` y `CapacityAlertJob` para no duplicar la recolección. Cada sección tiene su propio `rescue`: si Redis cae, la página `/admin/health` sigue renderizando (muestra `redis_error`) en vez de explotar — el worker caído es justo cuando más se necesita ver el estado.
- **Alertas vía Sentry, no un canal nuevo.** Sentry ya está integrado; `CapacityAlertJob` emite `capture_message(level: :warning)` en vez de montar email/Slack propio. Reusa la infraestructura de observabilidad existente.
- **Umbrales como `Setting` (0 = off).** `capacity_queue_latency_alert_seconds` y `capacity_backlog_alert_threshold` se ajustan sin deploy; ambos en 0 hacen el job no-op. Categoría `admin` (existente) para no tocar `CATEGORIES`.
- **Sin métricas de host todavía.** Para un solo host Hetzner, latencia de cola + memoria Redis cubren el 80% del riesgo de saturación. `node_exporter`/CPU-RAM-disco se difiere; no justifica el peso para un host.
- **Skip del visor de conversaciones en tiempo real (roadmap 3.4).** Requería ActionCable+Turbo en el panel admin, pero el layout admin **no carga JavaScript** (solo `stylesheet_link_tag`; el JS es inline vanilla para el drawer de ayuda) y `cable.js` tiene un error de sintaxis (`export consumer =`), señal de que el cliente ActionCable nunca se cableó. Habilitarlo exige pipeline de assets + Turbo en admin + verificación en navegador (no confiable headless). Se difiere conscientemente; el roadmap asumía "ActionCable+turbo ya están" pero del lado cliente no lo están.

## Detección de habilidades + coaching personalizado (05-jun-2026)

- **Las 82 habilidades son competencias del participante (humano), no skills de la IA.** El usuario aportó 83 `.txt` de habilidades blandas (liderazgo, manejo de conflictos, acción imperfecta…). Se modelan como catálogo de **lo que la persona puede desarrollar**, no como herramientas/instrucciones del agente: la IA las usa como knowledge-base (RAG ligero) para detectar qué competencia aflora y coachear sobre ella. No son skills ejecutables tipo Claude Code.
- **LLM-tag en vez de embeddings/pgvector.** La detección la hace `gpt-4.1-mini` en modo JSON eligiendo slugs de un catálogo cacheado, no similitud vectorial. Razón: cero infra nueva (sin pgvector ni reindex), reusa el stack OpenAI y el patrón de prompt-caching de `ProgramManifesto` (catálogo como prefijo estable del system prompt). Las "señales de que te falta X" de cada habilidad son cues etiquetados que el clasificador matchea directo. Embeddings queda como mejora si la precisión no alcanza.
- **Detección async, coaching diferido un turno.** `TagConversationSkillsJob` corre después de responder (no añade latencia). La inyección de coaching usa la **habilidad dominante acumulada** (más detectada en 30 días), no la del mensaje actual — el loop es conversación N detecta → N+1 coachea. Evita bloquear la respuesta esperando el tagging.
- **Parser por prefijo de cabecera, no por línea exacta.** Las secciones varían el sufijo ("Señales de estrés crónico", "Prácticas que ayudan a cuidarla", "Ejercicios para cuidar la energía"). `Skills::TextParser` matchea cabeceras por prefijo (`/\ASeñales\b/`, etc.) sobre líneas no indentadas; el cuerpo se agrupa en items por bullet/número/"Ejercicio". Validado: 82/82 sin secciones vacías.
- **Dedup por slug, gana el menor número.** `06_paciencia_intelectual` y `08_paciencia_intelectual` son dos variantes (data vs tech-lead) con el mismo slug. El importer conserva la primera (menor número) y omite el resto: 82 únicas de 83 archivos. Idempotente (upsert por slug), seguro re-correr tras editar la fuente.
- **Kill-switches default ON pero auto-seguros.** `skill_tagging_enabled` y `skill_coaching_injection_enabled` arrancan en true porque la feature es el objetivo, pero el tagger no llama a OpenAI si el catálogo no está sembrado (`Skill.active` vacío) — no hay costo sorpresa antes del seed.
