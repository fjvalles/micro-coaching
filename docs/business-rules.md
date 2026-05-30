# Reglas de Negocio

Fuente canónica. Cada regla: **enunciado** + **por qué** + **dónde se enforce** (`path:line`).

Si una regla cambia en código sin actualizar este doc → bug de proceso. Ver skill `business-rules` para mantenimiento.

---

## 1. Programa

### 1.1 Duración estándar = 14 días
- **Regla.** Programa tiene `total_days` (default 14). Días numerados 1..total_days. Día `total_days + 1` = estado completado.
- **Por qué.** Modelo de cambio conductual de 14 días dividido en fases see/choose/anchor.
- **Enforce.** `app/models/program.rb:8` (validación), `app/services/participants/day_advancer.rb:20` (lectura con fallback 14).

### 1.2 Fases del contenido diario
- **Regla.** Cada `DayContent` pertenece a una fase: `see` | `choose` | `anchor`.
- **Por qué.** Estructura pedagógica del programa.
- **Enforce.** `DayContent#phase`, expuesto vía `Participant#phase`.

### 1.2.b `DayContent` siempre pertenece a un programa
- **Regla.** No existen contenidos diarios huérfanos; todo `DayContent` debe tener `program_id`.
- **Por qué.** La operación admin y la ejecución del programa ya trabajan con contenido versionado por programa. Permitir contenidos globales vuelve ambiguo qué secuencia usa cada participante.
- **Enforce.** `app/models/day_content.rb:2-10`, `db/migrate/20260523223000_require_program_on_day_contents.rb`.

### 1.3 Día 15 = manifesto
- **Regla.** Al completar día 14 con check-in válido, se envía manifesto generado por IA y `status: :completed`.
- **Por qué.** Cierre del programa, refuerzo del aprendizaje.
- **Enforce.** `app/services/participants/day_advancer.rb:32-35`, `GenerateAndSendManifestoJob`.

---

## 2. Enrollment

### 2.1 Enrollment crea participante en estado `:active`
- **Regla.** `Participants::Enroller` crea con `status: :active`, `current_day: 1`, `enrolled_at` y `started_at` = ahora. Dispara `SendWelcomeJob`.
- **Por qué.** No hay flujo de opt-in diferido; el alta administrativa = comienzo del programa.
- **Enforce.** `app/services/participants/enroller.rb:11-25`.

### 2.2 Timezone obligatorio
- **Regla.** Default `America/Santiago` (vía `ENV["DEFAULT_TIMEZONE"]`). Validación de presencia.
- **Por qué.** Todos los cron jobs filtran por hora local; sin TZ no se puede broadcast.
- **Enforce.** `app/models/participant.rb:14`, `app/services/participants/enroller.rb:3`.

### 2.3 Teléfono único en formato E.164
- **Regla.** `phone_e164` único, formato `^\+\d{8,15}$`.
- **Por qué.** Meta API exige E.164. Único = previene duplicar conversaciones.
- **Enforce.** `app/models/participant.rb:12-13`.

### 2.4 Programa default al enrollar
- **Regla.** Si no se pasa programa, usa `Program.default` (primer activo por `created_at`).
- **Por qué.** Operación admin típica = un solo programa vivo.
- **Enforce.** `app/services/participants/enroller.rb:6`, `app/models/program.rb:13-15`.

---

## 3. Estados del participante

### 3.1 Enum
- `pending` — creado pero no activo (rara vez usado; Enroller activa directamente)
- `active` — recibiendo mensajes
- `completed` — terminó día 14 con check-in
- `paused` — admin pausó manualmente

### 3.2 Solo `:active` recibe mensajes broadcast
- **Regla.** `MorningWakeJob`, `CheckinEveningJob`, `AdvanceDayJob` solo procesan `:active`.
- **Por qué.** `paused` y `completed` no deben recibir nuevos mensajes.
- **Enforce.** Filtros en cada job + `DayAdvancer:8`.

### 3.3 El estado se puede cambiar desde el panel de administración
- **Regla.** El estado del participante (pending, active, completed, paused) se puede editar directamente desde el formulario del participante en el panel de administración.
- **Por qué.** El panel nativo ofrece flexibilidad completa de administración.
- **Enforce.** `app/views/admin/participants/_form.html.erb:30-33` (selector de estado).

### 3.4 Soft delete vía `discard`
- **Regla.** `Participant` y `Conversation` usan `discard` gem. Toda query usa scope `.kept`.
- **Por qué.** Borrado físico de un participante pierde historia de auditoría / costos de IA.
- **Enforce.** `app/models/participant.rb:17`, `app/models/conversation.rb:22`.

---

## 4. Cadencia diaria

### 4.1 Despertar a `wake_hour` local
- **Regla.** `MorningWakeJob` corre cada hora UTC; para cada `:active`, envía si hora local == `Setting.get("wake_hour")` (default 7).
- **Por qué.** Despertar relevante al huso del participante, sin un cron por TZ.
- **Enforce.** `config/schedule.yml:1-4`, `MorningWakeJob`, filtrado por `participant.local_time`.

### 4.2 IAReto = despertar + `iareto_delay_minutes`
- **Regla.** `SendIaretoJob` se encola con `wait:` igual a `Setting.get("iareto_delay_minutes")` (default 30).
- **Por qué.** Espacio entre despertar y reto para que el participante lo absorba.
- **Enforce.** `app/jobs/morning_wake_for_participant_job.rb:28-29`.

### 4.3 IAReto: free-form si dentro de 24h, template si no
- **Regla.** Si participante respondió en últimas 24h (`in_24h_window?`), IAReto va como `send_text`. Si no, como template aprobado.
- **Por qué.** Política Meta de ventana de servicio al cliente. Free-form fuera de ventana = baneo.
- **Enforce.** `app/models/participant.rb:31-36`, `SendIaretoJob`.

### 4.4 Check-in vespertino a las 20:00 local
- **Regla.** `CheckinEveningJob` corre cada hora UTC; envía si hora local == 20.
- **Por qué.** Reflexión al final del día. Hora fija (no configurable hoy).
- **Enforce.** `config/schedule.yml:6-9`, `CheckinEveningJob`.

### 4.5 Check-in marca `pending_checkin_at`
- **Regla.** Al enviar check-in, set `participant.pending_checkin_at = Time.current`. Habilita clasificación posterior.
- **Por qué.** `MessageClassifier` necesita marcar ventana de respuesta esperada.
- **Enforce.** `app/jobs/checkin_for_participant_job.rb:30`.

### 4.6 Avance de día a 06:00 UTC
- **Regla.** `AdvanceDayJob` corre diario 06:00 UTC. Para cada `:active`, llama `DayAdvancer`.
- **Por qué.** Hora global fija para simplificar; el avance respeta la fecha local del participante.
- **Enforce.** `config/schedule.yml:11-14`.

---

## 5. Avance de día

### 5.1 Solo avanza si hubo check-in **hoy local**
- **Regla.** `DayAdvancer` retorna `:no_checkin` si no existe `Conversation(moment: :checkin_response, day_number: current_day)` creada en la fecha local del participante.
- **Por qué.** El día no se "consume" si el participante no respondió. Avanzar sin respuesta = perder oportunidad de coaching.
- **Enforce.** `app/services/participants/day_advancer.rb:11-18`.

### 5.2 Sin re-engagement automático
- **Regla.** Si participante se calla N días, el `current_day` se queda. No hay nudge ni cambio de estado.
- **Por qué.** Decisión consciente (ver `docs/decisions.md`). Re-engagement requiere diseño de copy y guardrails que aún no existen.

### 5.3 Completar = `current_day >= total_days`
- **Regla.** Al avanzar desde `total_days` con check-in válido: `status = :completed`, `completed_at = ahora`, `current_day = total_days + 1`. Encola manifesto.
- **Por qué.** Sentinel `total_days + 1` distingue "completado" de "día válido".
- **Enforce.** `app/services/participants/day_advancer.rb:21-23, 32-35`.

---

## 6. Mensajería entrante

### 6.1 Lookup por `phone_e164`
- **Regla.** Inbound buscado por `+{from}` y `{from}`. Si no existe `:kept` → descartar silenciosamente.
- **Por qué.** Meta a veces envía `from` sin `+`. Descartar evita procesar números desconocidos.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:25-27`.

### 6.2 Audio se transcribe y analiza; otros media se rechazan
- **Regla.** Mensajes `type in [audio, voice]` se descargan vía `Whatsapp::MediaFetcher`, se transcriben con `Openai::AudioTranscriber` y se analizan paralingüísticamente con `Openai::VoiceAnalyzer`. La transcripción reemplaza al `body` de la `Conversation` y se persiste también en la columna `transcription`; el análisis (tono, emoción primaria/secundaria, energía, ritmo, volumen, cualidades vocales, sentimiento, observaciones) se guarda en `voice_analysis` (jsonb). Luego el flujo continúa idéntico al de texto (clasificación + respuesta libre o check-in).
- **Restricciones.** Audios con `duration > audio_max_duration_seconds` (default 180s) se persisten transcritos pero responden con copy "audio muy largo" sin generar respuesta IA. Si `audio_processing_enabled = false`, se vuelve al copy de rechazo.
- **Fallback.** Otros tipos (`image`, `video`, `document`) o `type != "text"` con `text.blank?` → `voice_message_reply_text` y no se procesa.
- **Por qué.** Capturar señal paralingüística (voz temblorosa, pausas, ritmo) que un participante no necesariamente verbaliza, y eliminar fricción para responder por voz. El análisis se inyecta como nota paralingüística al prompt del modelo generativo, sin contaminar la transcripción literal.
- **Enforce.** `app/jobs/process_incoming_message_job.rb` (`process_audio_message`, `enrich_with_voice`), `app/services/participants/audio_processor.rb`.

### 6.3 Toda inbound se persiste como `Conversation`
- **Regla.** Antes de clasificar, se crea `Conversation(moment: :free_user, role: :user)`. Luego el moment se reescribe según clasificación (`:welcome` o `:checkin_response`).
- **Por qué.** Auditoría completa. Pérdida de un inbound = pérdida de evidencia.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:45-53`.
### 6.4 Registro de números desconocidos
- **Regla.** Si un mensaje proviene de un número que no corresponde a ningún participante en el sistema, se registra en `UnknownInbound` y no se envía ninguna respuesta al remitente.
- **Por qué.** Evitar costos innecesarios en llamadas a la API de OpenAI y llamadas de WhatsApp para remitentes accidentales o spam, a la vez que se mantiene trazabilidad para auditorías.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:30-32` y `app/jobs/process_incoming_message_job.rb:171-186`.

---

## 7. Clasificación inbound

`Participants::MessageClassifier` retorna uno de tres tipos:

### 7.1 `:initial_pattern_answer`
- **Condición.** `participant.initial_pattern.blank?` Y existe `Conversation(moment: :welcome)`.
- **Efecto.** Set `initial_pattern = text`, reescribe inbound a `moment: :welcome`, envía ack "Mañana empieza tu primer día".
- **Enforce.** `app/services/participants/message_classifier.rb:20-22`, `process_incoming_message_job.rb:47-50`.

### 7.2 `:checkin_response`
- **Condición.** Hora local en `CHECKIN_WINDOW = 20..23` Y `pending_checkin_at` mismo día local Y no existe ya `Conversation(moment: :checkin_response, day_number: current_day)`.
- **Efecto.** Reescribe a `moment: :checkin_response`, llama `Openai::CheckinSummarizer`, crea `DailyReport`, ack "Gracias. Mañana retomamos".
- **Enforce.** `app/services/participants/message_classifier.rb:24-36`, `process_incoming_message_job.rb:59-77`.

### 7.3 `:free_user` (default)
- **Condición.** Cualquier otra cosa.
- **Efecto.** Llama `Openai::FreeResponseGenerator`, ack con `moment: :free_assistant`.
- **Enforce.** `process_incoming_message_job.rb:79-87`.

---

## 8. Comunicación saliente (WhatsApp)

### 8.1 Ventana de 24h para free-form
- **Regla.** `Whatsapp::Client#send_text` solo válido si última inbound del participante < 24h. Fuera de ventana → usar template aprobado.
- **Por qué.** Política Meta. Free-form fuera de ventana = strike y eventual baneo del número.
- **Enforce.** `app/models/participant.rb:31-36` (predicate), `app/jobs/send_iareto_job.rb:14`, `app/jobs/checkin_for_participant_job.rb:17`.
- **Gap.** Free-form acks en `ProcessIncomingMessageJob#ack` (línea 90) no consultan la ventana — asumen que el participante acaba de escribir. Cierto siempre que `ack` se llama desde dentro del flujo de procesamiento de inbound. Documentar invariante si se reutiliza `ack` desde otro contexto.

### 8.2 Templates pre-aprobados, params genéricos
- **Regla.** 4 templates cubren los 14 días vía `{{1}}`, `{{2}}`:
  - `bienvenida`
  - `despertar_dia_NN` (param: cuerpo generado por IA)
  - `iareto_dia_NN`
  - `checkin_dia_NN`
- **Por qué.** Meta exige aprobación manual por template. 4 plantillas << 28+.
- **Enforce.** `Whatsapp::TemplateSender`, `DayContent#template_name_whatsapp` con fallback `"despertar_dia_%02d"`.

### 8.3 Locale = `ENV["PROGRAM_LOCALE"]` (default `es_MX`)
- **Regla.** Todos los templates usan este locale. Cambiarlo requiere registrar templates con ese locale en Meta.
- **Enforce.** `Whatsapp::TemplateSender`.

### 8.4 Firma de webhook obligatoria
- **Regla.** Toda inbound de Meta verifica `X-Hub-Signature-256` con `secure_compare`. Sin firma válida → 401.
- **Por qué.** Endpoint público. Sin verificación, cualquiera inyecta mensajes.
- **Enforce.** `Whatsapp::SignatureVerifier`, `WebhooksController`.

### 8.5 Retries automáticos del cliente
- **Regla.** `Whatsapp::Client` reintenta 3× con backoff exponencial en 429 y 5xx. Callers no envuelven en retry.
- **Enforce.** `app/services/whatsapp/client.rb`.

---

## 9. Idempotencia de jobs

### 9.1 Despertar idempotente por día
- **Regla.** `MorningWakeForParticipantJob` verifica `Conversation(moment: :morning_wake, day_number: current_day, created_at >= hoy_local.beginning_of_day)` antes de enviar.
- **Por qué.** Sidekiq reintenta. Mensaje duplicado = burned trust.
- **Enforce.** `app/jobs/morning_wake_for_participant_job.rb:9-14`.

### 9.2 Check-in y IAReto siguen el mismo patrón
- **Regla.** Antes de enviar, query por `moment + day_number`. Si ya existe en el día local → no enviar.

### 9.3 Status updates de Meta no sobreescriben timestamps
- **Regla.** `delivered_at` y `read_at` solo se setean si están vacíos. `failed` siempre escribe `error_message`.
- **Por qué.** Meta envía multiples status events; conservar el primer timestamp es correcto.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:17-21`.

---

## 10. Generación con IA

### 10.1 Modelo fijo: `gpt-4.1-mini`
- **Por qué.** Costo/calidad balanceado para mensajes cortos en español.

### 10.2 Temperaturas
- `0.75` generativo (despertar, IAReto, free response, manifesto).
- `0.3` JSON estructurado (`CheckinSummarizer`).
- **Por qué.** JSON requiere salida estable; generativo necesita variación.

### 10.3 Prompt caching obligatorio
- **Regla.** Todo system prompt empieza con `Openai::ProgramManifesto::TEXT` (~1.2k tokens, compartido).
- **Por qué.** OpenAI cachea ≥1024 tokens reutilizados en ~5min. Skip = 5–10× costo.
- **Enforce.** `app/services/openai/program_manifesto.rb`, prepend en todos los generators.

### 10.4 JSON con fallback
- **Regla.** `response_format: { type: "json_object" }` + rescue `JSON::ParserError` → degradar a texto raw, nunca raise.
- **Por qué.** El summarizer es best-effort. Una falla de parse no debe romper el flujo del participante.
- **Enforce.** `Openai::CheckinSummarizer`.

### 10.5 Dry-run soportado
- **Regla.** Todo generator acepta `dry_run: true` → retorna `Result` con `prompt_used` lleno y sin llamada API.
- **Por qué.** Preview admin, tests, iteración de prompts sin gastar tokens.

### 10.6 Token accounting persistido
- **Regla.** `Conversation` guarda `prompt_used` (text), `model_used` (string), `tokens_input` (int), `tokens_output` (int) en cada mensaje generado por IA.
- **Por qué.** Auditoría de costos por participante / día.
- **Enforce.** Columnas: `db/schema.rb` (tabla `conversations`). Escritura: `app/jobs/process_incoming_message_job.rb:74-76, 84-86`.

---

## 11. Persistencia de mensajes

### 11.1 `Conversation` es source-of-truth
- **Regla.** Todo mensaje (in/out, user/assistant) se persiste. Sin excepciones.
- **Por qué.** Reconstrucción de historia, debugging, contexto para IA, evidencia.

### 11.2 `day_number` siempre stampado
- **Regla.** Cada `Conversation` lleva `day_number = participant.current_day` al momento del evento.
- **Por qué.** Permite query por día sin recalcular fecha → estado.

### 11.3 `DailyReport` solo en check-in válido
- **Regla.** Un `DailyReport` por (participante, día) cuando el check-in se procesa exitosamente.
- **Por qué.** Reporte ≠ conversación. Reporte = análisis estructurado del día.
- **Enforce.** `process_incoming_message_job.rb:65-72`.

---

## 12. Configuración vía `Setting`

### 12.1 Keys conocidas
- `wake_hour` — hora local 0..23, default 7
- `iareto_delay_minutes` — entero, default 30

### 12.2 Cambio en vivo
- **Regla.** Cambiar un `Setting` afecta el próximo tick de cron. No requiere deploy ni reinicio.
- **Enforce.** `Setting.get(key)` se lee en cada ejecución de job.

---

## 12.bis Registro y mejora de prompts IA

### 12.bis.1 Toda llamada a OpenAI queda registrada
- **Regla.** Cada generador (`MorningMessageGenerator`, `FreeResponseGenerator`, `CheckinSummarizer`, `ManifestoGenerator`, `VoiceAnalyzer`) escribe un `PromptExecution` por invocación con input renderizado, output, tokens y latencia.
- **Por qué.** Iterar sobre prompts con datos reales en lugar de logs efímeros.
- **Enforce.** `Openai::PromptLogger.record` al final de cada `#call`. Fallos del logger no abortan la respuesta (rescue + warn).

### 12.bis.2 Cada edición de prompt crea versión
- **Regla.** `PromptTemplate#record_version!` snapshotea un `PromptVersion` cuando el body cambia. Mismo body no duplica.
- **Orígenes:** `service` (auto-captura), `day_content` (edición de `DayContent.ai_system_prompt`), `admin` (UI), `analysis` (aplicar sugerencia IA).

### 12.bis.3 Sección vs día
- Templates de sección (`morning_message`, `free_response`, `checkin_summarizer`, `manifesto`, `voice_analyzer`): `day_number` nil.
- Template `day_system_prompt`: una fila por (`program_id`, `day_number`), refleja `DayContent.ai_system_prompt`.

### 12.bis.4 Análisis IA on-demand
- **Regla.** `/admin/prompt_templates/:id/analyze` encola `AnalyzePromptJob` → `Openai::PromptCritic` toma las últimas 20 ejecuciones y devuelve `findings + suggested_body + rationale` persistidos en `PromptAnalysis`.
## 14. Modos de Respuesta y Supervisión Humana (Human-in-the-loop)

### 14.1 Resolución de modo de respuesta (Precedencia)
- **Regla.** El modo de respuesta para un participante se resuelve buscando en orden de prioridad: el modo específico del participante (`Participant#response_mode`), el modo del programa (`Program#response_mode`), el valor del setting global (`Setting.fetch("response_mode")`), y finalmente el valor predeterminado `"auto"`.
- **Por qué.** Permitir control granular (supervisar un participante en particular o un programa piloto) sin perder la capacidad de configurar el comportamiento del sistema de manera global.
- **Enforce.** `app/services/response_mode.rb:7-15`.

### 14.2 Comportamiento del Dispatcher según el modo
- **Regla.** `Outbound::Dispatcher` determina la acción según el modo de respuesta resuelto:
  - `auto`: Envía el mensaje inmediatamente por WhatsApp y crea una `Conversation`.
  - `approve` / `suggest`: Genera el borrador con IA, crea un registro `PendingResponse` en estado `pending`, e inicia el mailer para notificar al administrador.
  - `manual`: Crea un registro `PendingResponse` en estado `pending` con borrador vacío, y notifica al administrador (sin generar respuesta IA automáticamente).
- **Por qué.** Garantizar la seguridad e intervención humana en diferentes niveles de confianza del sistema antes de enviar mensajes reales por WhatsApp.
- **Enforce.** `app/services/outbound/dispatcher.rb:25-54`.

### 14.3 Aprobación y Rechazo de Respuestas Pendientes
- **Regla.** El administrador puede editar, aprobar (`SendApprovedJob`) o rechazar un `PendingResponse` desde la interfaz. Aprobarlo desencadena el envío por la API de WhatsApp, la creación de la respectiva `Conversation`, y actualiza el estado de la respuesta pendiente a `sent` o `approved` con la marca del administrador (`approved_by_id`).
- **Por qué.** Mantener la consistencia del chat y el registro de auditoría de quién aprobó la interacción.
- **Enforce.** `app/controllers/admin/pending_responses_controller.rb`.

---

## 15. Sistema de Aprendizaje Continuo (Methodology Insights)

### 15.1 Generación de Insights Nocturnos
- **Regla.** El cron `RefreshMethodologyInsightsJob` se ejecuta todas las noches a las 03:30 UTC para recalcular y guardar vistas agregadas del rendimiento del coaching y prompts en la tabla `methodology_insights`.
- **Por qué.** Ofrecer un panel consolidado de métricas sin penalizar el rendimiento del panel de administración en tiempo de consulta.
- **Enforce.** `config/schedule.yml:21-24`, `app/services/methodology/insight_builder.rb`.

### 15.2 Tipos de Insights Soportados
- **Regla.** Se calculan y actualizan 6 scopes agregados en el payload JSONB:
  - `key_pattern_cluster`: Temas recurrentes en las respuestas de check-in (mediante `Openai::PatternClusterer`).
  - `voice_trend_by_phase`: Tendencia de tono y emoción por fase pedagógica del participante.
  - `prompt_finding_digest`: Resumen de fallas y debilidades identificadas por `PromptCritic`.
  - `phase_kpi`: Métricas de engagement (tasa de respuesta, longitud de caracteres, audios) por fase.
  - `stuck_pattern`: Alertas de participantes que llevan 3+ días en el mismo patrón de check-in.
  - `prompt_evolution`: Comparativa de latencia y tokens entre versiones de prompts.
- **Por qué.** Cubrir las fases de Observe, Evaluate e Improve en el ciclo de mejora de prompt engineering.
- **Enforce.** `app/services/methodology/insight_builder.rb`.

---

## 16. Límites de uso, auto-pausa e identidad del coach

### 16.1 Tope diario de mensajes libres (`max_free_messages_per_day`)
- Solo aplica a la conversación **libre** (`handle_free`), no a check-ins ni al patrón inicial.
- Se cuenta `Participant#free_inbounds_today`: mensajes entrantes con `moment: free_user` en el **día local** del participante. Los inbounds reclasificados a `welcome`/`checkin_response` ya no cuentan.
- Al superar el tope, se envía **una sola vez** `free_messages_cap_reply_text` (en el mensaje que cruza el límite, `used == cap + 1`) y luego se guarda silencio hasta el día siguiente. No se llama a OpenAI mientras esté topeado.
- `0` = sin límite. **Enforce:** `ProcessIncomingMessageJob#free_cap_reached?`.

### 16.2 Auto-pausa por inactividad (`inactivity_pause_days`)
- `PauseInactiveParticipantsJob` (cron diario, 05:00 UTC) pausa participantes `active` sin **ningún mensaje entrante** en los últimos N días.
- Ventana de gracia: no pausa a quien se enroló hace menos de N días (`enrolled_at`).
- Un mensaje entrante **reactiva** automáticamente al participante (`ProcessIncomingMessageJob#reactivate_if_paused`, `status: active`), auditado con `whodunnit: system:InboundReactivation`.
- `0` = nunca pausar. Pausas y reactivaciones quedan en PaperTrail con `source: system`.

### 16.3 Nombre del coach (`coach_name`)
- Setting global de texto. Si está presente, `Openai::ProgramManifesto.call` anexa la identidad del coach al system prompt de **todas** las llamadas generativas (matinal, libre, check-in, manifiesto), humanizando la interacción.
- Vacío = sin nombre (comportamiento previo). El override por empresa llegará con el modelo `Company`.

---

## 17. Observabilidad y errores

- **Sentry** captura excepciones de web y Sidekiq cuando `SENTRY_DSN` está presente; inerte si no.
- **Privacidad (Ley 19.628):** `send_default_pii = false` y `before_send` aplica un scrubber recursivo (`ImpulsoSentryScrub`) que redacta teléfonos, emails y claves sensibles (`body`, `raw_text`, `transcription`, `initial_pattern`, etc.) antes de enviar cualquier evento. **Nunca** sale PII cruda hacia el tercero.
- Excepciones ruidosas no accionables (`RecordNotFound`, `RoutingError`, `InvalidAuthenticityToken`) se excluyen. Alertas (email/Slack) se configuran en el proyecto Sentry.

---

## 18. Empresas (multi-tenant)

### 18.1 `Company` agrupa participantes
- `Participant#company_id` → `Company` (opcional). Un participante puede ser **individual** (sin empresa) o pertenecer a una empresa.
- ⚠️ `belongs_to :company` **sombrea** la columna string legacy `company`. El valor legacy se lee con `participant[:company]`; la asociación con `participant.company`. El alta pública (`Participants::Enroller`) sigue escribiendo el string legacy para mapeo posterior.

### 18.2 Programas generales vs por empresa
- `Program#company_id` nulo = **general** (disponible para todos). Con empresa = **exclusivo** de esa empresa.
- `Program.available_to(company)` = generales + los de esa empresa. `Program.default` prefiere un programa general activo.

### 18.3 Coach por empresa
- `Company#coach_name` sobrescribe el `coach_name` global. `Participant#coach_name` devuelve el override de su empresa (o nil → global). Se inyecta vía `Openai::ProgramManifesto.call(program, coach_name:)`.

### 18.4 Membresía y pago
- `Company#covers_membership` (default true): si la empresa cubre, sus miembros **no pagan individualmente**. `Participant#pays_individually?` = sin empresa, o empresa que no cubre.
- Regla de portal (Fase 3): un miembro de empresa no podrá modificar su membresía ni datos asociados; los gestiona la empresa/admin.

---

## 19. Pagos (Webpay Plus / Transbank)

### 19.1 Flujo
- `/pagos` (público) muestra el precio (`membership_price_clp`, IVA incluido) → `POST /pagos` crea un `Payment` (pending), inicia transacción Webpay (`Webpay::Client#create`) y redirige a Transbank.
- Transbank retorna a `/pagos/retorno`: `token_ws` = flujo normal → `commit`; `TBK_TOKEN` = el usuario abandonó → `aborted`.
- `commit` es **idempotente**: un refresh/segundo retorno no vuelve a confirmar (si ya está `authorized`/`rejected`, solo re-renderiza).

### 19.2 Kill-switch y ambiente
- `webpay_enabled` (default false) corta el inicio de transacciones. `webpay_environment` = `integration` (credenciales de prueba del SDK) o `production` (usa `WEBPAY_COMMERCE_CODE`/`WEBPAY_API_KEY`).

### 19.3 Ingresos, comisión e IVA
- `Payment#amount` es bruto con IVA incluido (CLP). `tax_amount` = IVA débito contenido; `net_of_tax` = neto de venta.
- Al confirmar, `assign_commission_snapshot!` congela `commission_amount` (comisión Transbank × `payment_commission_rate`, + IVA) y `net_amount` (bruto − comisión).
- `/admin/payments` (Ingresos) agrega bruto, IVA débito, neto ventas, comisión Transbank y neto recibido por período. Independiente del tracker de costos (USD) en `/admin/finances`.

### 19.4 Quién paga
- Individuos (sin empresa) pagan su membresía. Miembros de empresa con `covers_membership` no pagan individualmente (`Participant#pays_individually?`). El gating del alta por pago se hará en el portal (Fase 3).

---

## 20. Portal del participante

### 20.1 Login passwordless (magic-link)
- `/portal/acceso`: el participante ingresa su email → se envía un enlace firmado (`Participant.generates_token_for :portal_login`, expira 30 min, se invalida si cambia el email).
- Respuesta **uniforme**: nunca se revela si el email existe (anti-enumeración). Rack-Attack limita 5/min por IP y 3/10min por email (anti email-bombing).
- `/portal/sesion/:token` valida el token, hace `reset_session` (anti session-fixation) y guarda `session[:portal_participant_id]` (cookie cifrada). `current_participant` vive en `ApplicationController`.

### 20.2 Cuenta (solo lectura en v1)
- `/portal` muestra progreso (día/total, fase, estado), reportes diarios propios y, si `pays_individually?` + `webpay_enabled` + precio > 0, un CTA de pago.
- El portal es **read-only**: no se editan datos. Esto satisface "el miembro de empresa no modifica su membresía"; la edición de perfil queda para una iteración futura.
- Layout `portal` es mobile-first y enlaza el manifest PWA para permitir "instalar como app".

---

## 13. Edge cases conocidos

- **Participante sin `DayContent`.** Si no existe `DayContent(program, current_day)`, `MorningWakeForParticipantJob` retorna sin enviar. Sin error.
- **Filtro admin sin resultados.** Si los filtros de `/admin/day_contents` no encuentran coincidencias, el panel muestra estado vacío y conserva el contexto del programa si aplica.
- **Phone con/sin `+`.** Lookup intenta ambos formatos. Storage siempre con `+`.
- **DST.** `local_time` usa `in_time_zone(timezone)`. El día del cambio de hora, el filtro `local.hour == wake_hour` puede saltar o duplicar una vez. Aceptado.
- **Webhook con `messages` vacío.** Solo `statuses`. Procesado normal (update de timestamps), no se crea Conversation.
- **AI fail.** `Openai::Client` con timeout o 5xx → Sidekiq retry estándar. No hay fallback humano.

---

## Actualización

Cuando código cambia una regla:
1. Buscar regla en este doc por sección.
2. Editar enunciado / por qué / línea de enforce.
3. Si la regla desaparece: tachar (~~strikethrough~~) con razón + fecha en `docs/decisions.md`.
4. Si es regla nueva: añadir a la sección apropiada con `path:line` exacto.

Nunca dejar este doc desincronizado del código. PR que toca lógica de negocio sin tocar este doc debería ser bounced en review.
