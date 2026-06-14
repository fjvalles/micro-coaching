# Reglas de Negocio

Fuente canónica. Cada regla: **enunciado** + **por qué** + **dónde se enforce** (`path:line`).

Si una regla cambia en código sin actualizar este doc → bug de proceso. Ver skill `business-rules` para mantenimiento.

---

## 1. Programa

### 1.1 Duración estándar = 14 días
- **Regla.** Programa tiene `total_days` (default 14). Días numerados 1..total_days. Día `total_days + 1` = estado completado.
- **Por qué.** Modelo de cambio conductual de 14 días dividido en fases see/choose/anchor.
- **Enforce.** `app/models/program.rb:8` (validación), `app/services/participants/day_advancer.rb:20` (lectura con fallback 14).

### 1.1.b `current_day` dentro del programa
- **Regla.** `Participant#current_day` debe estar entre 0 y `program.total_days`; solo participantes `completed` pueden quedar en `program.total_days + 1`.
- **Por qué.** Evita estados imposibles desde el admin sin romper el día 0 de pre-inicio ni el sentinel de completado.
- **Enforce.** `app/models/participant.rb:26-30`, `app/models/participant.rb:131-138`.

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

### 2.5 Pregunta de patrón inicial no se envía si ya fue respondida
- **Regla.** `SendWelcomeQuestionJob` no envía la pregunta de patrón inicial si `Participant#initial_pattern` ya está presente, si ya existe una conversación `welcome` de usuario, o si la misma pregunta ya fue enviada.
- **Por qué.** El job se agenda con delay; si Sidekiq drena jobs atrasados o el participante responde rápido, la pregunta se vuelve obsoleta y confunde el flujo.
- **Enforce.** `app/jobs/send_welcome_question_job.rb`.

---

## 3. Estados del participante

### 3.1 Enum
- `pending` — creado pero no activo (rara vez usado; Enroller activa directamente cuando no se requiere pago)
- `active` — recibiendo mensajes
- `completed` — terminó día 14 con check-in
- `paused` — admin pausó manualmente o auto-pausa por inactividad (§16.2)
- `awaiting_payment` — alta de individuo que debe pagar antes de activarse (§21). El pago confirmado lo activa vía `Participants::Activator`. No recibe mensajes broadcast.

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

### 4.4 Check-in vespertino a `checkin_hour` local
- **Regla.** `CheckinEveningJob` corre cada hora UTC; envía si hora local == `Setting.fetch("checkin_hour")` (default 20).
- **Por qué.** Reflexión al final del día, ajustable sin deploy para programas o cohortes que necesitan otro horario.
- **Enforce.** `config/schedule.yml:6-9`, `app/jobs/checkin_evening_job.rb:4-13`.

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
- **Regla.** Antes de clasificar, se crea `Conversation(moment: :free_user, role: :user)`. Luego el moment se reescribe según clasificación (`:welcome` o `:checkin_response`) y se persiste `inbound_intent` / `inbound_intent_confidence` / `inbound_intent_reason` cuando aplica.
- **Por qué.** Auditoría completa. Pérdida de un inbound = pérdida de evidencia.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:47-57`, `app/jobs/process_incoming_message_job.rb:250-256`.
### 6.4 Registro de números desconocidos
- **Regla.** Si un mensaje proviene de un número que no corresponde a ningún participante en el sistema, se registra en `UnknownInbound` y no se envía ninguna respuesta al remitente.
- **Por qué.** Evitar costos innecesarios en llamadas a la API de OpenAI y llamadas de WhatsApp para remitentes accidentales o spam, a la vez que se mantiene trazabilidad para auditorías.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:30-32` y `app/jobs/process_incoming_message_job.rb:300-315`.

---

## 7. Clasificación inbound

La clasificación ocurre en dos capas. `Participants::MessageClassifier` decide por estado/ventana operacional. `Participants::InboundIntentClassifier` decide por significado semántico antes de consumir check-ins o derivar excepciones.

### 7.1 `:initial_pattern_answer`
- **Condición.** `participant.initial_pattern.blank?` Y existe `Conversation(moment: :welcome)`.
- **Efecto.** Set `initial_pattern = text`, reescribe inbound a `moment: :welcome`, envía ack "Mañana empieza tu primer día".
- **Enforce.** `app/services/participants/message_classifier.rb:20-22`, `app/jobs/process_incoming_message_job.rb:96-110`.

### 7.2 `:checkin_response`
- **Condición.** Hora local en `CHECKIN_WINDOW = 20..23` Y `pending_checkin_at` mismo día local Y no existe ya `Conversation(moment: :checkin_response, day_number: current_day)`.
- **Efecto.** Antes de consumirlo, `InboundIntentClassifier` debe clasificar el mensaje como `checkin_answer` con confianza mínima `inbound_intent_min_confidence`. Solo entonces reescribe a `moment: :checkin_response`, llama `Openai::CheckinSummarizer`, crea `DailyReport`, ack "Gracias. Mañana retomamos".
- **Enforce.** `app/services/participants/message_classifier.rb:24-36`, `app/services/participants/inbound_intent_classifier.rb`, `app/jobs/process_incoming_message_job.rb:111-133`.

### 7.3 `:free_user` (default)
- **Condición.** Cualquier otra cosa, o un mensaje recibido con check-in pendiente que semánticamente no es `checkin_answer`.
- **Efecto.** Llama `Openai::FreeResponseGenerator`, ack con `moment: :free_assistant`. Si había check-in pendiente, se inyecta contexto operativo para responder y recordar que el check-in sigue pendiente.
- **Enforce.** `app/jobs/process_incoming_message_job.rb:132-144`, `app/jobs/process_incoming_message_job.rb:182-198`, `app/services/openai/free_response_generator.rb:50-90`.

### 7.4 Intents semánticos especiales
- **Regla.** `InboundIntentClassifier` puede retornar `program_question`, `support_request`, `restricted_information_request`, `off_topic`, `risk_or_sensitive`, `stop_or_pause`, `unclear` o `checkin_answer`. `support_request` y `risk_or_sensitive` se derivan a `PendingResponse` en modo `approve` sin generar respuesta libre. `stop_or_pause` pausa al participante y responde con `pause_request_reply_text`.
- **Por qué.** Evitar que preguntas administrativas, mensajes sensibles o pedidos de baja se mezclen con la memoria metodológica del programa.
- **Enforce.** `app/services/participants/inbound_intent_classifier.rb:3-228`, `app/jobs/process_incoming_message_job.rb:200-256`.

### 7.5 Bloqueo de información restringida
- **Regla.** Si un participante pide datos propios, datos de otros, métricas/listados de la app, nombres, teléfonos, empresas, prompts, metodología interna o retos/preguntas futuras, se clasifica como `restricted_information_request` y se responde solo `restricted_information_reply_text`. No se llama a `FreeResponseGenerator`, no se crea `DailyReport`, no se etiqueta habilidad y no se guarda como patrón inicial.
- **Por qué.** WhatsApp no es un canal autenticado para exponer datos ni contenidos internos/futuros del programa; además evita alucinación de datos por parte de la IA.
- **Enforce.** `app/services/participants/inbound_intent_classifier.rb:92-107`, `app/services/participants/inbound_intent_classifier.rb:147-152`, `app/services/participants/inbound_intent_classifier.rb:206-227`, `app/jobs/process_incoming_message_job.rb:96-103`, `app/jobs/process_incoming_message_job.rb:216-235`.

---

## 8. Comunicación saliente (WhatsApp)

### 8.1 Ventana de 24h para free-form
- **Regla.** `Whatsapp::Client#send_text` solo válido si última inbound del participante < 24h. Fuera de ventana → usar template aprobado.
- **Por qué.** Política Meta. Free-form fuera de ventana = strike y eventual baneo del número.
- **Enforce.** `app/models/participant.rb:31-36` (predicate), `app/jobs/send_iareto_job.rb:14`, `app/jobs/checkin_for_participant_job.rb:17`.
- **Gap.** Free-form acks en `ProcessIncomingMessageJob#ack` (línea 90) no consultan la ventana — asumen que el participante acaba de escribir. Cierto siempre que `ack` se llama desde dentro del flujo de procesamiento de inbound. Documentar invariante si se reutiliza `ack` desde otro contexto.

### 8.2 Templates pre-aprobados, params genéricos
- **Regla.** Los programas usan templates genéricos vía `{{1}}`, `{{2}}`: `bienvenida_piloto`, `despertar_dia_NN`, `iareto_dia_NN`, `checkin_dia_NN`. Para programas de más de 14 días, `NN` cicla sobre 01..14.
- **Por qué.** Meta exige aprobación por template; variables genéricas permiten reutilizar el set aprobado sin registrar contenido clínico o metodológico específico.
- **Enforce.** `Whatsapp::TemplateSender`, `Whatsapp::DailyTemplateName`, `DayContent#template_name_whatsapp`, `scripts/create_whatsapp_templates.rb`.

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

### 8.6 Envío manual desde el panel (admin)
- **Regla.** El admin puede enviar un mensaje a un participante (individual, en `/admin/participants/:id`) o a varios seleccionados (masivo, desde el índice) — texto libre o una plantilla curada. Todo pasa por `Outbound::AdminMessage`, que despacha vía `Outbound::Dispatcher` con `mode: "auto"` (el admin **es** el revisor humano, nunca encola un `PendingResponse`) y `moment: :admin_manual`.
- **24h.** El texto libre solo se envía si `participant.in_24h_window?`; fuera de ventana se omite (`skipped_reason: :outside_24h_window`) y la UI deshabilita la opción. Las plantillas se envían siempre. Mismo invariante que §8.1 — no se elude la política Meta.
- **Masivo.** `broadcast` encola `BroadcastMessageJob`, que hace fan-out a un `SendAdminMessageJob` por participante (patrón fan-out, no loop en el request). Cada job reaplica la guarda de 24h: el texto fuera de ventana se omite por participante, las plantillas llegan a todos. No es idempotente a propósito (el admin puede reenviar).
- **Plantillas (catálogo derivado).** `Whatsapp::AdminTemplateCatalog` arma el selector automáticamente: `bienvenida_piloto` (siempre) + por cada `DayContent` activo del programa del participante, `despertar_dia_NN` / `iareto_dia_NN` / `checkin_dia_NN` — exactamente los nombres que envían los cron jobs, así el dropdown solo lista plantillas que existen en Meta para ese programa. Las variables vienen **prellenadas** donde el contenido es estático (nombre, texto IARETO, preguntas del check-in); el "mensaje" del despertar queda en blanco porque lo genera la IA. El admin ya no edita JSON a mano.
- **Plantillas extra (Setting opcional).** El Setting `admin_message_templates` (JSON: `[{name, label, variables}]`) se **agrega** al catálogo para plantillas Meta que no derivan del programa; se dedupea por `name` (el catálogo del programa gana). Vacío = solo las derivadas. En el composer de masivo (sin participante) solo se listan `bienvenida_piloto` + las del Setting, porque las plantillas por día llevan contenido específico del participante que no se comparte en un broadcast.
- **Enforce.** `app/services/whatsapp/admin_template_catalog.rb`, `app/services/outbound/admin_message.rb`, `app/jobs/broadcast_message_job.rb`, `app/jobs/send_admin_message_job.rb`, `Admin::ParticipantsController#send_message`/`#broadcast`.

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

### 10.1 Modelo mínimo por tarea
- **Regla.** Las llamadas de texto usan `Openai::ModelRouter` con settings por tarea (`openai_model_<task>`) y fallback a `openai_model`.
- **Defaults.** `gpt-5-nano` para preview/check-in/summary/clasificación/tagging/clustering, `gpt-5-mini` para respuesta libre/matinal/manifiesto/PromptCritic. Audio conserva `gpt-4o-mini-transcribe` y `gpt-4o-mini-audio-preview`.
- **Por qué.** Reducir costo en tareas simples de alto volumen sin degradar los puntos user-facing que requieren más matiz.
- **Enforce.** `app/services/openai/model_router.rb`, `Openai::Client#chat(task:)`.

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
- `checkin_hour` — hora local 0..23, default 20
- `iareto_delay_minutes` — entero, default 30
- `inbound_intent_classification_enabled` — boolean, default true; habilita clasificación semántica de inbound
- `inbound_intent_min_confidence` — float 0..1, default 0.65; umbral para consumir un inbound como check-in real
- `openai_max_tokens_inbound_intent` — entero, default 220; token budget del clasificador semántico
- `checkin_pending_followup_text` — texto inyectado cuando hay check-in pendiente pero el inbound no es check-in
- `restricted_information_reply_text` — texto fijo para bloquear solicitudes de datos, metodología, prompts o contenidos futuros
- `support_request_review_reply_text` / `sensitive_request_review_reply_text` / `pause_request_reply_text` — borradores operativos para soporte, temas sensibles y pausa

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

> Pagos one-time (membresía). Para cobro recurrente ver §22 (Oneclick). El alta gateada por pago: §21.

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
- Individuos (sin empresa) pagan su membresía. Miembros de empresa con `covers_membership` no pagan individualmente (`Participant#pays_individually?`).
- El gating del alta por pago está **enforced** (§21).

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

## 21. Alta gateada por pago (individuos)

### 21.1 Cuándo aplica
- **Regla.** `Participant#payment_required?` = `pays_individually?` **Y** `membership_price_clp > 0` **Y** `webpay_enabled`. Solo entonces el alta se gatea por pago.
- **Por qué.** Miembros cubiertos por empresa, o cuando los pagos están apagados / precio en 0, no deben bloquearse: se activan de inmediato.
- **Enforce.** `app/models/participant.rb#payment_required?`.

### 21.2 Flujo
- `Participants::Enroller`: si `payment_required?`, crea el participante en `:awaiting_payment` (`current_day: 0`, sin `started_at`, **sin** `SendWelcomeJob`). Si no, activa de inmediato vía `Participants::Activator`.
- Alta pública (`home#enroll`): tras crear, si quedó `awaiting_payment` → redirige a `/pagos?participant_id=…`. El resto ve la página de arranque de WhatsApp.
- `PaymentsController#commit`: al autorizar, si el participante está `awaiting_payment`, `Participants::Activator` lo activa (día 1 + bienvenida). Idempotente.

### 21.3 `Participants::Activator` (ruta única de activación)
- **Regla.** Toda activación pasa por `Activator`: setea `status: :active`, `current_day: 1`, `enrolled_at`/`started_at` (si faltan) y encola `SendWelcomeJob`. Es **idempotente** (no-op + sin bienvenida si ya está `active`).
- **Por qué.** Antes la lógica "activar + bienvenida" estaba duplicada en `Enroller` y el admin enroll. Una sola ruta evita dobles bienvenidas y comportamiento divergente.
- **Enforce.** `app/services/participants/activator.rb`; usado por `Enroller`, `Admin::ParticipantsController#enroll`, `PaymentsController#commit`, y `SubscriptionsController` (primer cobro).

### 21.4 Inicio inmediato desde admin
- **Regla.** El admin puede usar "Empezar programa ahora" para participantes con programa en día 0/1: asegura estado active día 1, enrollment, bienvenida si falta, y encola el despertar sin esperar el horario normal.
- **Por qué.** Permite iniciar una inscripción manual inmediatamente sin copiar mensajes ni esperar el próximo cron, preservando jobs/idempotencia.
- **Enforce.** `app/services/participants/program_starter.rb:14-24`, `app/controllers/admin/participants_controller.rb:152-161`, `app/views/admin/participants/show.html.erb:30-38`.

---

## 22. Suscripciones recurrentes (Webpay Oneclick)

> ⚠️ **Build completo, producción pendiente.** El kill-switch `webpay_oneclick_enabled` permanece **OFF** hasta tener y verificar credenciales productivas de Transbank Oneclick. Las credenciales de integración del SDK funcionan en dev/test.

### 22.1 Inscripción + primer cobro
- `/suscripcion` (público) muestra `subscription_price_clp` → `POST /suscripcion` crea una `Subscription` (`pending`), inicia la inscripción de tarjeta (`Webpay::OneclickClient#start_inscription`) y redirige a Transbank.
- Retorno en `/suscripcion/retorno`: `finish_inscription` obtiene el token recurrente (`tbk_user`); luego se hace el **primer cobro** (`charge`). Si autoriza → `Subscription` `active`, se registra un `Payment` ligado, y si el participante estaba `awaiting_payment` se activa (§21.3). Sin token = `aborted`/`canceled`.

### 22.2 Cobro recurrente y dunning
- `SubscriptionBillingJob` (cron diario 08:00 UTC) cobra las suscripciones `active` cuyo `next_billing_at <= now` (`Subscription.billable`).
- **Idempotente:** un cobro exitoso avanza `next_billing_at` (sale del scope `billable`); un fallo reprograma a mañana e incrementa `failed_attempts`. Re-correr el mismo día no duplica cobros.
- **Dunning:** superados `subscription_max_retries`, la suscripción pasa a `past_due` y se emite aviso a Sentry. `0 = sin recurrencia`.
- **Enforce.** `app/jobs/subscription_billing_job.rb`, `app/models/subscription.rb` (`billable`, `schedule_next_cycle!`, `record_charge!`).

### 22.3 Tokenización (seguridad)
- Solo se almacena el token recurrente de Transbank (`tbk_user` + `tbk_username`), **nunca** el número de tarjeta. El cobro usa el token contra el commerce code hijo del Mall.

### 22.4 Visibilidad
- `/admin/subscriptions`: conteo de activas, MRR (suma de `amount_clp` de activas, IVA incl.) y desglose por estado. Cada cobro aparece en `/admin/payments` como `Payment` ligado a su `Subscription`.

---

## 23. Resultado consolidado (P&L CLP/USD)

### 23.1 Conversión y margen
- **Regla.** `/admin/resultado` compara **ingreso recibido** (CLP, `Payment` autorizados netos de comisión Transbank) contra **costos operativos** (USD de `Finances::CostCalculator`) convertidos a CLP con el Setting manual `usd_clp_rate`. Margen = ingreso recibido − costos (CLP).
- **Por qué.** Ingresos nacen en CLP (Webpay) y costos en USD (OpenAI, hosting). Sin un tipo de cambio común no hay una sola vista de margen.
- **Enforce.** `app/controllers/admin/profit_loss_controller.rb`, `app/services/finances/cost_calculator.rb`. Tipo de cambio en `Setting "usd_clp_rate"` (auto-fetch es mejora futura).

### 23.2 Fuente única de costos
- **Regla.** El cálculo de costos USD (precios OpenAI por modelo + prorrateo de costos fijos) vive solo en `Finances::CostCalculator`; tanto Finanzas como Resultado lo consumen.
- **Por qué.** Evita que las dos vistas diverjan en precios o en la matemática de prorrateo.
- **Desgloses.** Finanzas muestra costo directo OpenAI por modelo, participante y programa desde `PromptExecution`. Las llamadas por tokens usan `tokens_input/output`; transcripción usa `billable_seconds` y precio estimado por minuto. Los fijos se mantienen como total prorrateado del período; no se reparten por participante/programa salvo que se defina una regla contable explícita.

---

## 24. Detección de habilidades y coaching personalizado

Catálogo de **habilidades humanas del participante** (no de la IA): 82 competencias de liderazgo/gestión/personales (escucha activa, manejo de conflictos, acción imperfecta, etc.), cada una con definición, señales, prácticas, gestos, ejercicios y preguntas de reflexión.

### 24.1 Catálogo (`Skill`)
- **Regla.** El catálogo se importa desde `db/seeds/skills_source/*.txt` vía `Skills::Importer` (parser `Skills::TextParser`). Slug derivado del nombre de archivo (sin prefijo numérico); upsert idempotente; en colisión de slug gana el archivo de menor número (ej.: dos variantes de `paciencia_intelectual` → 82 únicas de 83 archivos).
- **Enforce.** `app/services/skills/importer.rb`, `app/services/skills/text_parser.rb`, `db/seeds/skills.rb`. Vista admin `/admin/skills`.

### 24.2 Detección (`SkillTagger` + `TagConversationSkillsJob`)
- **Regla.** Tras cada mensaje entrante de **check-in** o **chat libre**, `TagConversationSkillsJob` (async) corre `Openai::SkillTagger`: el modelo clasifica el texto contra el catálogo (slug + señales, modo JSON) y devuelve 0–3 habilidades con confianza. Cada una sobre `skill_tagging_min_confidence` se persiste como `SkillDetection` (participante + conversación + skill + origen).
- **Por qué.** Las "señales de que te falta X" de cada habilidad son cues etiquetados; el catálogo va como prefijo estable del system prompt para aprovechar prompt caching (patrón `ProgramManifesto`). Async para no añadir latencia a la respuesta.
- **Idempotencia.** Si la conversación ya tiene detecciones, se omite; índice único `[conversation_id, skill_id]` ante re-entrega de webhook.
- **Fallback.** Errores OpenAI no retryables `400 Bad Request` degradan a cero tags para no llenar la retry queue; 429/5xx/timeouts siguen el retry estándar.
- **Kill-switch.** `skill_tagging_enabled` (default true). Sin catálogo sembrado, el tagger no llama a OpenAI.
- **Enforce.** `app/jobs/tag_conversation_skills_job.rb`, `app/services/openai/skill_tagger.rb`, `app/services/openai/skill_catalog.rb`, hook en `app/jobs/process_incoming_message_job.rb` (`enqueue_skill_tagging`).

### 24.3 Coaching personalizado (`Skills::CoachingHint`)
- **Regla.** Los mensajes generativos (respuesta libre + matinal) inyectan una sugerencia de coaching sobre la **habilidad dominante** del participante: la más detectada en los últimos 30 días. La sugerencia incluye una práctica, un gesto y un micro-ejercicio del catálogo, con instrucción de integrarlo con naturalidad (no nombrarlo como "habilidad detectada").
- **Por qué.** Cierra el loop: la conversación N detecta la habilidad → la conversación N+1 coachea sobre ella de forma concreta en vez de genérica.
- **Kill-switch.** `skill_coaching_injection_enabled` (default true).
- **Enforce.** `app/services/skills/coaching_hint.rb`, inyección en `Openai::FreeResponseGenerator#system_prompt` y `Openai::MorningMessageGenerator#system_prompt`. Perfil por participante en `/admin/participants/:id` y `/admin/skills`.

---

## 25. Memoria de coaching y privacidad del prompt

Tres campos de "memoria" por participante, separados por **quién los escribe** y **si llegan a la IA**. La invariante central: el contexto sensible crudo nunca toca un prompt.

### 25.1 `coach_notes` — humano, jamás a la IA
- **Regla.** Texto libre del operador con el contexto crudo/sensible del participante. Editable solo en `/admin/participants/:id`. **Nunca** se inyecta en ningún servicio `Openai::`.
- **Por qué.** El operador (human-in-the-loop) necesita el contexto real para revisar `PendingResponse`, elegir programa y decidir envíos manuales — sin que ese contexto pueda filtrarse en un mensaje generado.
- **Enforce.** `app/models/participant.rb` (columna + validación de largo), permit en `Admin::ParticipantsController#participant_params`. Comentarios-guarda en `FreeResponseGenerator#system_prompt` y `MorningMessageGenerator#user_prompt`. Spec: `spec/services/openai/coaching_memory_injection_spec.rb` (verifica que `coach_notes` no aparece en los prompts).

### 25.2 `focus_hint` — humano, abstracto, sí a la IA
- **Regla.** Directriz abstracta de hacia dónde empujar (ej. "acompañar hacia activación física y autonomía"). Editable en admin. **Sí** se inyecta en los mensajes generativos.
- **Por qué.** Personaliza hacia el objetivo sin sostener los hechos que expondrían al participante. Si la IA "filtrara" su instrucción, lo peor que sale es la directriz abstracta, no el diagnóstico.
- **Enforce.** Inyectado en `Openai::FreeResponseGenerator#system_prompt` y `Openai::MorningMessageGenerator#user_prompt`.

### 25.3 `ai_summary` — la IA, rodante, sí a la IA
- **Regla.** Resumen evolutivo del participante que `RefreshParticipantSummaryJob` actualiza (async) tras cada `checkin_response`, vía `Openai::ParticipantSummarizer`. Abstracto (conducta + progreso, sin etiquetas clínicas). Se inyecta en los mensajes generativos. Read-only en admin.
- **Por qué.** La memoria viva de la IA era solo las últimas 5 conversaciones + el último reporte; matices viejos se caían de la ventana. El resumen rodante los conserva → continuidad de coaching en programas largos.
- **Kill-switch.** `participant_summary_enabled` (default true). Off = no se llama a OpenAI para resumir y no se inyecta.
- **Enforce.** `app/jobs/refresh_participant_summary_job.rb`, `app/services/openai/participant_summarizer.rb`, hook en `app/jobs/process_incoming_message_job.rb` (rama `:checkin_response`). El campo no está en `participant_params` (lo escribe solo el job).

---

## 26. Ciclos y multi-programa (`Enrollment`)

Modelo **secuencial**: un participante corre un programa a la vez (`Participant#program_id` + `current_day` siguen siendo la fuente viva). `Enrollment` es un **ledger histórico** de los ciclos recorridos, no la fuente de verdad del estado vivo.

### 26.1 `Enrollment` registra cada ciclo
- **Regla.** Cada vez que un participante empieza un programa se abre una fila `Enrollment` (`participant`, `program`, `cycle_number`, `status` active/completed/canceled, `started_at`, `completed_at`). `cycle_number` es global por participante (reusar el mismo programa luego → ciclo único nuevo). Índice único `[participant_id, program_id, cycle_number]`.
- **Por qué.** Historial de qué programas corrió y cómo terminó cada uno, habilitando journeys multi-ciclo (Nivel 1 → Nivel 2) sin refactorizar el estado core ni meter un join en el hot path de los crons.
- **Enforce.** `app/models/enrollment.rb`, `Participant#start_enrollment!` (idempotente: no duplica fila active para el mismo programa), `db/migrate/20260613120002_create_enrollments.rb`.

### 26.2 Activación abre el ciclo 1
- **Regla.** `Participants::Activator` llama `start_enrollment!` al activar → ciclo 1 active para el programa actual.
- **Enforce.** `app/services/participants/activator.rb`.

### 26.3 Completar cierra el ciclo
- **Regla.** Al completar el día final (`DayAdvancer#complete!`), el `current_enrollment` pasa a `completed` con `completed_at`.
- **Enforce.** `app/services/participants/day_advancer.rb`.

### 26.4 Re-enrollment al programa siguiente
- **Regla.** `Participants::ReEnroller` mueve al participante al `program.next_program` (o uno explícito): repunta `program_id`, `current_day: 1`, `status: active`, abre nuevo ciclo, cancela cualquier ciclo active del programa anterior, resetea `ai_summary` (memoria limpia para el nuevo journey) y dispara `SendWelcomeJob`. `next_program_id` es una FK self-referencial en `Program` (nil = sin siguiente).
- **Por qué.** El multi-ciclo es secuencial; el reset de memoria evita arrastrar contexto del programa anterior.
- **Trigger.** Botón "Avanzar a {siguiente}" en `/admin/participants/:id` (visible solo si el participante está `completed` y el programa tiene `next_program`) → `Admin::ParticipantsController#re_enroll`.
- **Enforce.** `app/services/participants/re_enroller.rb`, `app/models/program.rb` (`belongs_to :next_program`), `app/controllers/admin/participants_controller.rb` (`#re_enroll`), `app/views/admin/participants/show.html.erb`, `db/migrate/20260613120001_add_next_program_to_programs.rb`.

---

## 27. Copiloto de operaciones (superadmin)

Chat interno en `/admin/copilot` que lee la base de datos y **propone** acciones de negocio. Es un agente OpenAI (function calling), corre **dentro de Rails** (no edita código, no hace deploy, no toca el filesystem). El riesgo central es prompt injection: el texto de participantes (que el copiloto puede leer) es dato no confiable que reentra al contexto del modelo.

### 27.1 Acceso solo superadmin + kill-switch
- **Regla.** Requiere `AdminUser#superadmin = true` **y** `Setting "copilot_enabled" = true` (default OFF). Sin ambos, la ruta responde 403 / redirige. Las sesiones se scopean al admin dueño.
- **Por qué.** Capacidad sensible (lee PII, ejecuta acciones). Superficie mínima: una persona de máxima confianza, apagada por defecto.
- **Enforce.** `app/controllers/admin/copilot_controller.rb` (`#require_superadmin`, `#require_copilot_enabled`), `app/jobs/copilot_agent_job.rb` (gate), checkbox en `app/views/admin/admin_users/_form.html.erb`.

### 27.2 Dos clases de herramientas: read (inmediata) y act (gateada)
- **Regla.** El catálogo es fijo (`Copilot::ToolRegistry`), dispatch por lookup de hash — un nombre del modelo nunca llega a `send`/`eval`. **Read tools** (`participant_lookup`, `participant_detail`, `recent_conversations`, `cohort_metrics`, `failed_messages`) ejecutan inline y devuelven datos. **Act tools** (`send_message`, `pause_participant`, `reactivate_participant`, `advance_day`) **nunca** ejecutan inline: el loop crea un `CopilotPendingAction` (pending) y se detiene.
- **Enforce.** `app/services/copilot/tool_registry.rb`, `app/services/copilot/read_tools.rb`, `app/services/copilot/agent_runner.rb`.

### 27.3 La aprobación humana es la defensa primaria contra injection
- **Regla.** Ninguna act tool corre sin que un superadmin la apruebe en la UI. La inyección, en el peor caso, produce una **propuesta** que un humano veta. Al aprobar, `Copilot::ActExecutor` **re-valida** los args (target resuelto a `Participant.kept` por id, nunca un teléfono libre; body ≤ 1500) y corre el servicio real (`Outbound::AdminMessage`, `Participants::DayAdvancer`, transición de status). La acción queda `executed`/`failed` con resultado.
- **Por qué.** El modelo no es de confianza para disparar acciones salientes; el gate convierte "RCE-via-chat" en "propuesta revisada".
- **Enforce.** `app/services/copilot/act_executor.rb`, `app/controllers/admin/copilot_controller.rb` (`#approve_action`).

### 27.4 Datos de herramientas son no confiables; PII y secretos acotados
- **Regla.** Los resultados de tools reentran como `role:"tool"` (nunca dentro del system prompt). El system prompt instruye ignorar cualquier instrucción incrustada en ese contenido. Las read tools seleccionan columnas explícitas PII-safe: **nunca** `coach_notes`, **nunca** tokens de pago/suscripción; el teléfono se enmascara a los últimos 4. `ai_summary`/`focus_hint` sí (son AI-safe por diseño).
- **Enforce.** `Copilot::AgentRunner#system_prompt`, `Copilot::ReadTools#participant_summary` / `#mask_phone`.

### 27.5 Topes por sesión
- **Regla.** `copilot_token_budget_per_session` (default 200k) detiene el loop al agotarse; `copilot_action_cap_per_session` (default 10) frena la creación de nuevas propuestas. Loop acotado a 6 iteraciones por turno.
- **Enforce.** `CopilotSession#over_token_budget?` / `#action_cap_reached?`, `Copilot::AgentRunner::MAX_ITERATIONS`.

### 27.6 Auditoría
- **Regla.** Cada turno (user/assistant/tool) se persiste append-only en `copilot_messages`; cada acción propuesta en `copilot_pending_actions` con `approved_by` + `executed_at`. La UI actualiza en vivo vía Turbo Streams.
- **Enforce.** `app/models/copilot_message.rb`, `app/models/copilot_pending_action.rb`.

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
