class Setting < ApplicationRecord
  VALUE_TYPES  = %w[string text integer float boolean json].freeze
  CATEGORIES   = %w[timing openai whatsapp program admin general finances copilot].freeze
  CACHE_PREFIX = "setting:".freeze
  CACHE_TTL    = 5.minutes
  DEFAULT_FREE_CHAT_STYLE_GUARDRAILS = <<~TEXT
    - No te quedes en bucle indagando sensaciones corporales. Si ya exploraste
      una sensación física durante 2 turnos, cierra esa línea y vuelve al patrón
      del día o a un gesto concreto. No eres terapeuta somático: el foco es el
      cambio de conducta, no el escaneo corporal infinito.
    - Varía cómo reconoces lo que dice la persona. Evita repetir muletillas como
      "Gracias por decirlo" o "Perfecto, gracias por compartir" en mensajes
      seguidos. A veces basta con responder sin acuse previo.
    - Respeta la autonomía. Si la persona pide flexibilidad o no quiere fijar una
      hora o estructura exacta, no insistas: acéptalo y ofrece un apoyo abierto.
      No repitas la misma pregunta (p. ej. "¿a qué hora?") si ya mostró resistencia.
    - Haz UNA sola pregunta por mensaje, nunca dos. No encadenes preguntas con
      "y" ni "o" (mal: "¿va lento o rápido, y qué cambia en tu respiración?").
      Elige la pregunta más importante y deja el resto para después. Si tus
      respuestas son cortas, no infles las tuyas.
    - Usa español chileno natural. Evita modismos ajenos a Chile como "te late",
      "órale", "ándale", "chido" o "vale" como muletilla.
  TEXT

  # Canonical schema. Add entries here; consumers read via Setting.fetch(key).
  # Each entry: type, category, description, default, optional validate proc.
  SCHEMA = {
    # ── timing ─────────────────────────────────────────────────────────────
    "wake_hour" => {
      type: :integer, category: "timing", default: 7,
      description: "Hora local (0–23) en que se dispara el mensaje matinal.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "checkin_hour" => {
      type: :integer, category: "timing", default: 20,
      description: "Hora local (0–23) en que se dispara el check-in nocturno.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "iareto_delay_minutes" => {
      type: :integer, category: "timing", default: 30,
      description: "Minutos entre el mensaje matinal y el envío del Iareto.",
      validate: ->(v) { (0..240).cover?(v) || "debe estar entre 0 y 240" }
    },
    "welcome_question_delay_minutes" => {
      type: :integer, category: "timing", default: 2,
      description: "Minutos entre la bienvenida y la pregunta de patrón inicial.",
      validate: ->(v) { (0..1440).cover?(v) || "debe estar entre 0 y 1440" }
    },
    "inactivity_pause_days" => {
      type: :integer, category: "timing", default: 5,
      description: "Días sin mensaje entrante antes de pausar al participante (PauseInactiveParticipantsJob, diario). 0 = nunca pausar. Un mensaje entrante lo reactiva.",
      validate: ->(v) { (0..30).cover?(v) || "debe estar entre 0 y 30" }
    },
    "default_timezone" => {
      type: :string, category: "timing", default: "America/Santiago",
      description: "Zona horaria fallback cuando el participante no tiene una asignada.",
      validate: ->(v) { ActiveSupport::TimeZone[v].present? || "zona horaria inválida" }
    },

    # ── openai ─────────────────────────────────────────────────────────────
    "openai_model" => {
      type: :string, category: "openai", default: "gpt-4.1-mini",
      description: "Modelo fallback de OpenAI cuando una tarea no tiene setting específico."
    },
    "openai_model_preview_challenge" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para la demo pública de desafío en la landing."
    },
    "openai_model_morning_message" => {
      type: :string, category: "openai", default: "gpt-5-mini",
      description: "Modelo para generar el mensaje matinal personalizado."
    },
    "openai_model_free_response" => {
      type: :string, category: "openai", default: "gpt-5-mini",
      description: "Modelo para respuestas libres al participante por WhatsApp."
    },
    "openai_model_inbound_intent_classifier" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para clasificar semánticamente mensajes entrantes."
    },
    "openai_model_checkin_summarizer" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para resumir check-ins nocturnos en JSON."
    },
    "openai_model_participant_summary" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para mantener el resumen rodante del participante."
    },
    "openai_model_skill_tagger" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para etiquetar habilidades humanas detectadas en mensajes."
    },
    "openai_model_manifesto" => {
      type: :string, category: "openai", default: "gpt-5-mini",
      description: "Modelo para generar el manifiesto de cierre."
    },
    "openai_model_pattern_clusterer" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para agrupar patrones recurrentes en metodología."
    },
    "openai_model_prompt_critic" => {
      type: :string, category: "openai", default: "gpt-5-mini",
      description: "Modelo para analizar y proponer mejoras de prompts."
    },
    "openai_model_guardrail_proposer" => {
      type: :string, category: "openai", default: "gpt-5-mini",
      description: "Modelo para proponer cambios acotados a los guardrails de respuesta libre."
    },
    "openai_model_resource_finder" => {
      type: :string, category: "openai", default: "gpt-4o-search-preview",
      description: "Modelo con búsqueda web para descubrir candidatos de recursos. Solo Resources::Finder puede crear URLs nuevas."
    },
    "openai_model_resource_verifier" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo juez para validar que una URL corresponda al tema declarado antes de revisión humana."
    },
    "openai_model_resource_gap_detector" => {
      type: :string, category: "openai", default: "gpt-5-nano",
      description: "Modelo para detectar si una conversación sugiere buscar un recurso curado."
    },
    "openai_temperature_generative" => {
      type: :float, category: "openai", default: 0.75,
      description: "Temperatura para llamadas generativas (matinal, libre, manifiesto).",
      validate: ->(v) { (0.0..2.0).cover?(v) || "debe estar entre 0.0 y 2.0" }
    },
    "openai_temperature_json" => {
      type: :float, category: "openai", default: 0.3,
      description: "Temperatura para llamadas de modo JSON (resumen de check-in).",
      validate: ->(v) { (0.0..2.0).cover?(v) || "debe estar entre 0.0 y 2.0" }
    },
    "openai_max_tokens_morning" => {
      type: :integer, category: "openai", default: 1024,
      description: "max_tokens del mensaje matinal. Con reasoning_effort=minimal el cap es salida pura; 1024 da margen amplio (mensajes matinales son cortos)."
    },
    "openai_max_tokens_free" => {
      type: :integer, category: "openai", default: 1024,
      description: "max_tokens de la respuesta libre. Con reasoning_effort=minimal el cap es salida pura; 1024 da margen amplio para el piloto (respuestas naturales ~80-292 tokens)."
    },
    "openai_max_tokens_checkin" => {
      type: :integer, category: "openai", default: 300,
      description: "max_tokens del resumen de check-in nocturno."
    },
    "openai_max_tokens_manifesto" => {
      type: :integer, category: "openai", default: 600,
      description: "max_tokens del manifiesto de cierre del día 15."
    },
    "openai_max_tokens_skill_tagging" => {
      type: :integer, category: "openai", default: 200,
      description: "max_tokens del etiquetado de habilidades (SkillTagger, modo JSON)."
    },
    "openai_max_tokens_inbound_intent" => {
      type: :integer, category: "openai", default: 220,
      description: "max_tokens del clasificador semántico de mensajes entrantes (InboundIntentClassifier, modo JSON)."
    },
    "openai_reasoning_effort" => {
      type: :string, category: "openai", default: "minimal",
      description: "reasoning_effort para modelos GPT-5. 'minimal' evita que los tokens de razonamiento consuman el cap de salida y devuelvan respuesta vacía. Opciones: minimal, low, medium, high.",
      validate: ->(v) { %w[minimal low medium high].include?(v.to_s) || "debe ser minimal, low, medium o high" }
    },
    "inbound_intent_classification_enabled" => {
      type: :boolean, category: "openai", default: true,
      description: "Kill-switch: si es true, clasifica semánticamente cada inbound libre/check-in para evitar consumir check-ins con mensajes fuera de contexto."
    },
    "inbound_intent_min_confidence" => {
      type: :float, category: "openai", default: 0.65,
      description: "Confianza mínima (0.0–1.0) para tratar un mensaje como respuesta real de check-in.",
      validate: ->(v) { (0.0..1.0).cover?(v) || "debe estar entre 0.0 y 1.0" }
    },
    "stop_or_pause_min_confidence" => {
      type: :float, category: "openai", default: 0.7,
      description: "Confianza mínima para ejecutar una pausa cuando el clasificador semántico devuelve stop_or_pause; señales ambiguas se degradan a unclear/reminder.",
      validate: ->(v) { (0.0..1.0).cover?(v) || "debe estar entre 0.0 y 1.0" }
    },
    "checkin_pending_followup_text" => {
      type: :text, category: "program",
      default: "Te respondo eso y dejo pendiente el check-in de hoy. Cuando puedas, responde las preguntas del día para cerrar el avance.",
      description: "Contexto operativo que se inyecta a la respuesta libre cuando un mensaje no es check-in pero llega con check-in pendiente."
    },
    "missed_checkin_reminder_text" => {
      type: :text, category: "program",
      default: "Antes de abrir el siguiente paso, cerremos el check-in pendiente. Responde las preguntas del día cuando puedas; con eso retomamos el avance.",
      description: "Mensaje matinal cuando el participante tiene pendiente el check-in de un día anterior; bloquea la cadencia normal hasta responder."
    },
    "support_request_review_reply_text" => {
      type: :text, category: "admin",
      default: "Recibí tu solicitud. La voy a dejar para revisión del equipo y te respondemos por este mismo canal.",
      description: "Borrador que queda pendiente para admin cuando un inbound parece soporte, pagos, horarios o solicitud humana."
    },
    "restricted_information_reply_text" => {
      type: :text, category: "program",
      default: "No puedo entregar datos de la aplicación, datos personales, metodología interna ni contenidos futuros del programa. Sigamos con el acompañamiento del día.",
      description: "Respuesta fija cuando el participante pide datos propios/de terceros, métricas, metodología interna, prompts o retos/preguntas futuras."
    },
    "task_acknowledgement_reply_text" => {
      type: :text, category: "program",
      default: "Perfecto, queda tomado. Te leo cuando cierres el día.",
      description: "Respuesta fija y breve cuando el participante confirma que hará el gesto/reto del día; evita repreguntar o abrir conversación libre."
    },
    "participant_reminders_enabled" => {
      type: :boolean, category: "program", default: true,
      description: "Kill-switch: si es true, un inbound puede programar recordatorios one-shot simples relacionados con el programa."
    },
    "participant_reminder_min_lead_minutes" => {
      type: :integer, category: "program", default: 2,
      description: "Anticipación mínima para programar un recordatorio solicitado por participante.",
      validate: ->(v) { (0..1440).cover?(v) || "debe estar entre 0 y 1440" }
    },
    "participant_reminder_max_horizon_days" => {
      type: :integer, category: "program", default: 30,
      description: "Horizonte máximo en días para recordatorios one-shot solicitados por participante.",
      validate: ->(v) { (1..365).cover?(v) || "debe estar entre 1 y 365" }
    },
    "participant_reminder_max_active" => {
      type: :integer, category: "program", default: 3,
      description: "Cantidad máxima de recordatorios pendientes por participante.",
      validate: ->(v) { (0..20).cover?(v) || "debe estar entre 0 y 20" }
    },
    "participant_reminder_max_per_day" => {
      type: :integer, category: "program", default: 2,
      description: "Cantidad máxima de recordatorios solicitados por participante para un mismo día local.",
      validate: ->(v) { (0..10).cover?(v) || "debe estar entre 0 y 10" }
    },
    "participant_reminder_quiet_hours_start" => {
      type: :integer, category: "program", default: 22,
      description: "Hora local de inicio de silencio para recordatorios solicitados por participante.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "participant_reminder_quiet_hours_end" => {
      type: :integer, category: "program", default: 7,
      description: "Hora local de término de silencio para recordatorios solicitados por participante.",
      validate: ->(v) { (0..23).cover?(v) || "debe estar entre 0 y 23" }
    },
    "participant_reminder_body_text" => {
      type: :text, category: "program",
      default: "Te recuerdo retomar el paso de hoy. Puedes hacer solo 5 minutos.",
      description: "Cuerpo del recordatorio one-shot enviado al participante. Soporta %{name} y %{day}."
    },
    "participant_reminder_scheduled_reply_text" => {
      type: :text, category: "program",
      default: "Listo, te aviso el %{when}.",
      description: "Confirmación fija cuando se agenda un recordatorio. Soporta %{when}."
    },
    "participant_reminder_rejected_reply_text" => {
      type: :text, category: "program",
      default: "Puedo programar recordatorios simples del programa con hora clara, por ejemplo: “avísame a las 5pm”. No agendé este porque está fuera de esos límites.",
      description: "Respuesta fija cuando un pedido de recordatorio no cumple límites de horario, horizonte, contenido o volumen."
    },
    "participant_reminder_disabled_reply_text" => {
      type: :text, category: "program",
      default: "Por ahora no puedo programar recordatorios desde el chat.",
      description: "Respuesta fija cuando el kill-switch de recordatorios está apagado."
    },
    "participant_reminder_template_name" => {
      type: :string, category: "whatsapp", default: "",
      description: "Template WhatsApp aprobado para recordatorios fuera de la ventana de 24h. Debe aceptar variables [nombre, cuerpo]. Vacío = falla fuera de ventana."
    },
    "sensitive_request_review_reply_text" => {
      type: :text, category: "admin",
      default: "Gracias por decirlo. Esto merece revisión humana cuidadosa; lo voy a dejar al equipo para que pueda responderte con más atención.",
      description: "Borrador que queda pendiente para admin cuando un inbound parece sensible o riesgoso."
    },
    "pause_request_reply_text" => {
      type: :text, category: "program",
      default: "Entendido, pausé tus mensajes del programa. Si quieres retomarlo, escríbenos por este mismo chat.",
      description: "Respuesta al participante cuando pide pausar o salir del programa."
    },
    "skill_tagging_enabled" => {
      type: :boolean, category: "openai", default: true,
      description: "Kill-switch: si es true, TagConversationSkillsJob detecta habilidades del participante en cada mensaje de check-in/libre. Sin catálogo de habilidades sembrado no llama a OpenAI."
    },
    "skill_tagging_min_confidence" => {
      type: :float, category: "openai", default: 0.55,
      description: "Confianza mínima (0.0–1.0) para persistir una habilidad detectada.",
      validate: ->(v) { (0.0..1.0).cover?(v) || "debe estar entre 0.0 y 1.0" }
    },
    "skill_coaching_injection_enabled" => {
      type: :boolean, category: "program", default: true,
      description: "Si es true, inyecta una sugerencia de coaching sobre la habilidad dominante del participante en los mensajes generativos (respuesta libre y matinal)."
    },
    "participant_summary_enabled" => {
      type: :boolean, category: "openai", default: true,
      description: "Kill-switch: si es true, RefreshParticipantSummaryJob mantiene un resumen rodante del participante (Participant#ai_summary) tras cada check-in y se inyecta en los mensajes generativos. Off = no se llama a OpenAI para resumir."
    },
    "openai_max_tokens_summary" => {
      type: :integer, category: "openai", default: 300,
      description: "max_tokens del resumen rodante del participante (ParticipantSummarizer)."
    },
    "openai_max_tokens_program" => {
      type: :integer, category: "openai", default: 4000,
      description: "max_tokens del generador de programas personalizados (ProgramGenerator, modo JSON). Un programa completo de varios días con 4 campos por día es grande."
    },
    "openai_max_tokens_resource_finder" => {
      type: :integer, category: "openai", default: 1500,
      description: "max_tokens del buscador de recursos con web search."
    },
    "resource_finder_max_candidates" => {
      type: :integer, category: "openai", default: 5,
      description: "Cantidad máxima de candidatos que Resources::Finder persiste por búsqueda.",
      validate: ->(v) { (1..10).cover?(v) || "debe estar entre 1 y 10" }
    },
    "program_intake_enabled" => {
      type: :boolean, category: "program", default: false,
      description: "Kill-switch: si es true, los participantes en estado :intake reciben el cuestionario por WhatsApp y se genera un programa personalizado con IA. Off = no se llama a OpenAI ni se genera nada."
    },
    "program_intake_review_required" => {
      type: :boolean, category: "program", default: true,
      description: "Si es true, el programa generado se crea como plantilla inactiva y queda pendiente de revisión humana antes de activarse para el participante (Programs::Approver). Off = activa el programa automáticamente."
    },
    "intake_opener_template" => {
      type: :string, category: "program", default: "bienvenida_piloto",
      description: "Nombre del template de WhatsApp (aprobado en Meta) usado como primer contacto del intake personalizado. Debe existir y estar aprobado; recibe 1 variable (nombre). El primer mensaje en frío no puede ser texto libre."
    },
    "program_intake_building_text" => {
      type: :text, category: "program",
      default: "¡Gracias! Con tus respuestas voy a preparar tu programa personalizado. Una persona del equipo lo revisa antes de activarlo para asegurar que sea el mejor para ti, así que puede tomar un poco. Te aviso por aquí en cuanto esté listo para empezar. 🙌",
      description: "Mensaje que recibe el participante al terminar el cuestionario de intake. Asume revisión humana (program_intake_review_required ON); si la desactivas, ajusta este texto."
    },
    "program_intake_failed_text" => {
      type: :text, category: "program",
      default: "Tuve un problema armando tu programa. Nuestro equipo lo revisará y te escribimos por aquí muy pronto.",
      description: "Mensaje al participante cuando la generación del programa personalizado falla."
    },
    "intake_abandonment_days" => {
      type: :integer, category: "program", default: 3,
      description: "Días sin actividad tras los que ExpireAbandonedIntakesJob saca a un participante estancado a mitad del intake (vuelve a :completed o :pending). 0 = desactivado.",
      validate: ->(v) { (0..60).cover?(v) || "debe estar entre 0 y 60" }
    },
    "nivel2_offer_enabled" => {
      type: :boolean, category: "program", default: false,
      description: "Kill-switch: si es true, al completar el programa gratis (día 14) se envía la oferta personalizada de Nivel 2 (SendNivel2OfferJob). Off = no se ofrece upsell."
    },
    "nivel2_offer_cta_text" => {
      type: :text, category: "program",
      default: "Si quieres seguir, armamos tu Nivel 2 a tu medida. Por haber completado estos 14 días tienes una oferta de fundador durante las próximas %{hours} horas, con garantía: si lo completas y no ves cambios, te damos un ciclo extra sin costo. ¿Lo diseñamos? Responde por aquí. 🙌",
      description: "Términos deterministas que SendNivel2OfferJob agrega bajo el mensaje generado por IA (oferta de día 14). Acepta %{hours} (= nivel2_offer_window_hours)."
    },
    "nivel2_offer_window_hours" => {
      type: :integer, category: "program", default: 48,
      description: "Duración (horas) de la ventana fundadora tras enviar la oferta de día 14: dentro de ella aplica founder_price_clp y el bono que expira. Ancla en Participant#nivel2_offer_sent_at.",
      validate: ->(v) { (1..720).cover?(v) || "debe estar entre 1 y 720" }
    },
    "guarantee_claim_window_days" => {
      type: :integer, category: "program", default: 30,
      description: "Días tras completar el Nivel 2 pagado en que el participante puede reclamar la garantía (ciclo extra gratis, una sola vez). 0 = garantía desactivada.",
      validate: ->(v) { (0..365).cover?(v) || "debe estar entre 0 y 365" }
    },
    "openai_retry_max" => {
      type: :integer, category: "openai", default: 3,
      description: "Intentos máximos ante errores 429/5xx/timeouts de OpenAI.",
      validate: ->(v) { (1..10).cover?(v) || "debe estar entre 1 y 10" }
    },
    "openai_dry_run_global" => {
      type: :boolean, category: "openai", default: false,
      description: "Kill-switch: si es true, ningún servicio llama a OpenAI (devuelve stub)."
    },
    "max_free_messages_per_day" => {
      type: :integer, category: "openai", default: 40,
      description: "Tope de mensajes libres (no-checkin) por participante por día. 0 = sin límite. Al superarlo, se envía free_messages_cap_reply_text una vez y se deja de responder hasta el día siguiente.",
      validate: ->(v) { (0..200).cover?(v) || "debe estar entre 0 y 200" }
    },
    "free_messages_cap_reply_text" => {
      type: :text, category: "openai",
      default: "Por hoy llegamos al límite de mensajes. Retomamos mañana con calma. 🙏",
      description: "Mensaje que se envía una vez cuando el participante supera max_free_messages_per_day."
    },
    "coach_name" => {
      type: :string, category: "openai", default: "",
      description: "Nombre del coach/asistente que firma las interacciones por WhatsApp. Se inyecta en el system prompt para humanizar. Vacío = sin nombre. (Override por empresa llega con el modelo Company.)"
    },
    "free_chat_style_guardrails" => {
      type: :text, category: "openai", default: DEFAULT_FREE_CHAT_STYLE_GUARDRAILS,
      description: "Bloque editable de estilo conversacional para Openai::FreeResponseGenerator. No incluye seguridad/privacidad ni memoria del participante."
    },
    "auto_prompt_tuning_enabled" => {
      type: :boolean, category: "openai", default: false,
      description: "Kill-switch maestro del auto-tuning de guardrails conversacionales."
    },
    "auto_prompt_tuning_mode" => {
      type: :string, category: "openai", default: "observe",
      description: "Modo del auto-tuning: observe registra score, propose crea propuestas para aprobar, apply aplica con rollback automático.",
      validate: ->(v) { %w[observe propose apply].include?(v.to_s) || "debe ser observe, propose o apply" }
    },
    "auto_tuning_score_threshold" => {
      type: :integer, category: "openai", default: 70,
      description: "Score mínimo aceptable de calidad conversacional. Bajo este valor se propone una mejora.",
      validate: ->(v) { (0..100).cover?(v) || "debe estar entre 0 y 100" }
    },
    "auto_tuning_rollback_margin" => {
      type: :integer, category: "openai", default: 5,
      description: "Caída de score contra baseline que dispara rollback automático.",
      validate: ->(v) { (0..100).cover?(v) || "debe estar entre 0 y 100" }
    },
    "auto_tuning_max_guardrails_chars" => {
      type: :integer, category: "openai", default: 1500,
      description: "Largo máximo permitido para el bloque editable de guardrails.",
      validate: ->(v) { (500..4000).cover?(v) || "debe estar entre 500 y 4000" }
    },
    "auto_tuning_sample_size" => {
      type: :integer, category: "openai", default: 30,
      description: "Cantidad máxima de mensajes recientes usados por AutoPromptTuningJob.",
      validate: ->(v) { (5..200).cover?(v) || "debe estar entre 5 y 200" }
    },

    # ── whatsapp ───────────────────────────────────────────────────────────
    "whatsapp_send_enabled" => {
      type: :boolean, category: "whatsapp", default: true,
      description: "Kill-switch: si es false, Whatsapp::Client no envía nada (modo mantenimiento)."
    },
    "whatsapp_self_signup_enabled" => {
      type: :boolean, category: "whatsapp", default: false,
      description: "Kill-switch: si es true, un número desconocido que escribe por WhatsApp se inscribe solo en la prueba gratis (ProcessIncomingMessageJob#maybe_self_signup). Off = solo se registra como UnknownInbound."
    },
    "whatsapp_retry_max" => {
      type: :integer, category: "whatsapp", default: 3,
      description: "Intentos máximos ante 429/5xx de Meta Cloud API.",
      validate: ->(v) { (1..10).cover?(v) || "debe estar entre 1 y 10" }
    },
    "meta_api_version" => {
      type: :string, category: "whatsapp", default: "v25.0",
      description: "Versión de Meta Graph API usada en envíos (override de la env var)."
    },
    "voice_message_reply_text" => {
      type: :text, category: "whatsapp",
      default: "Por ahora solo puedo procesar texto, por favor escribe tu respuesta.",
      description: "Texto que se envía cuando llega un mensaje no-texto (imagen, video, documento) y el procesamiento de audio está desactivado."
    },
    "audio_processing_enabled" => {
      type: :boolean, category: "whatsapp", default: true,
      description: "Si es true, los mensajes de audio/voz se descargan, transcriben y analizan. Si es false, se responde con voice_message_reply_text."
    },
    "audio_max_duration_seconds" => {
      type: :integer, category: "whatsapp", default: 180,
      description: "Duración máxima (segundos) de un audio aceptado. Audios más largos reciben voice_message_reply_text.",
      validate: ->(v) { (10..600).cover?(v) || "debe estar entre 10 y 600" }
    },
    "openai_transcription_model" => {
      type: :string, category: "openai", default: "gpt-4o-mini-transcribe",
      description: "Modelo de OpenAI usado para transcribir audios entrantes (whisper-1, gpt-4o-mini-transcribe, gpt-4o-transcribe)."
    },
    "openai_voice_analysis_model" => {
      type: :string, category: "openai", default: "gpt-4o-mini-audio-preview",
      description: "Modelo multimodal de audio usado para inferir tono/emoción/ritmo a partir del audio (gpt-4o-audio-preview, gpt-4o-mini-audio-preview)."
    },
    "openai_voice_analysis_enabled" => {
      type: :boolean, category: "openai", default: true,
      description: "Kill-switch del análisis paralingüístico (tono/emoción). Si es false, solo se transcribe."
    },
    "admin_message_templates" => {
      type: :json, category: "whatsapp", default: [],
      description: "Lista curada de plantillas WhatsApp aprobadas que el admin puede enviar manualmente desde el panel. Array de objetos {name, label, variables}: name = nombre exacto de la plantilla en Meta; label = etiqueta legible en el panel; variables = array de nombres de los placeholders del cuerpo ({{1}}, {{2}}…) en orden, vacío si la plantilla no tiene variables.",
      validate: ->(v) {
        next "debe ser una lista" unless v.is_a?(Array)
        v.all? { |t| t.is_a?(Hash) && t["name"].present? } || "cada plantilla necesita un 'name'"
      }
    },

    # ── program ────────────────────────────────────────────────────────────
    "response_mode" => {
      type: :string, category: "program", default: "auto",
      description: "Modo de respuesta global: auto (IA envía sola), approve (IA genera, admin aprueba), suggest (admin escribe con sugerencia IA), manual (admin responde todo).",
      validate: ->(v) { %w[auto approve suggest manual].include?(v.to_s) || "debe ser auto, approve, suggest o manual" }
    },
    "resource_catalog_enabled" => {
      type: :boolean, category: "program", default: false,
      description: "Kill-switch: si es true, respuestas generativas pueden anexar recursos aprobados del catálogo por ID."
    },
    "resource_autodiscovery_enabled" => {
      type: :boolean, category: "openai", default: false,
      description: "Kill-switch: si es true, conversaciones pueden disparar detección de gaps y búsqueda web automática de candidatos."
    },
    "resource_review_required" => {
      type: :boolean, category: "program", default: true,
      description: "Si es true, los recursos verificados quedan pendientes de aprobación humana antes de ser enviables."
    },
    "resource_revalidation_days" => {
      type: :integer, category: "program", default: 30,
      description: "Días tras los cuales un recurso se considera stale y debe revalidarse.",
      validate: ->(v) { (1..365).cover?(v) || "debe estar entre 1 y 365" }
    },
    "link_preview_enabled" => {
      type: :boolean, category: "program", default: false,
      description: "Si es true, Whatsapp::Client habilita preview_url cuando se anexa un link aprobado del catálogo."
    },
    "program_manifesto" => {
      type: :text, category: "program",
      default: <<~TEXT,
        Eres parte de un programa de 14 días que acompaña a la persona a
        salir del modo reactivo a través de tres fases — VER (días 1–4), ELEGIR (días 5–10) y
        ANCLAR (días 11–14). Principios:

        1. No enseñar, sino activar. No das consejos no pedidos.
        2. La persona descubre, tú reflejas. Usa preguntas más que respuestas.
        3. Brevedad. Máximo 4 frases. Sin emojis. Español chileno natural.
        4. Tono: cálido, lúcido, sin paternalismo. Sin coaching grandilocuente.
        5. Honra lo pequeño. Una micro-elección vale más que un gran propósito.
        6. Refleja lo que la persona ya dijo antes de añadir nada nuevo.

        Tu salida llega por WhatsApp, así que evita listas largas y formato markdown.
      TEXT
      description: "System prompt global prepended a todas las llamadas OpenAI (fallback si Program#manifesto está vacío)."
    },
    "privacy_policy" => {
      type: :text, category: "program",
      default: <<~TEXT,
        La presente Política de Privacidad describe cómo **Comtraining** ("nosotros", "el Responsable") recopila, usa, almacena y protege los datos personales de quienes participan en el programa de coaching **Impulso**, impartido a través de la plataforma de mensajería WhatsApp. Esta política se rige por la **Ley N.° 19.628 sobre Protección de la Vida Privada** de Chile y sus modificaciones vigentes.

        #### 1. Responsable del tratamiento
        **Comtraining**
        País de constitución: Chile
        Correo de contacto: [info@comtraining.cl](mailto:info@comtraining.cl)
        Sitio web: [https://www.comtraining.cl](https://www.comtraining.cl)

        Para consultas relacionadas con el tratamiento de sus datos personales puede escribirnos al correo indicado en la sección 9 de este documento.

        #### 2. Datos personales que recopilamos
        Recopilamos únicamente los datos necesarios para prestar el servicio de coaching:
        * **Datos de identificación y contacto:** nombre completo, número de teléfono de WhatsApp, correo electrónico corporativo, cargo/rol de liderazgo y empresa u organización.
        * **Mensajes de texto:** conversaciones enviadas y recibidas a través de WhatsApp durante el programa (14 días).
        * **Datos de seguimiento del programa:** respuestas a los retos diarios, resúmenes del check-in, mapas de energía generados y avance del programa.
        * **Mensajes de audio:** si envía mensajes de voz, estos se descargan de forma temporal, se transcriben a texto y se analizan para extraer tono/emoción para el proceso de coaching, tras lo cual el archivo de audio se elimina.

        No usamos cookies de rastreo ni herramientas de analítica de terceros en nuestra plataforma.

        #### 3. Finalidades del tratamiento
        Sus datos son tratados para las siguientes finalidades:
        * **Prestación del servicio:** enviar mensajes de coaching programados, procesar respuestas, realizar transcripción/análisis de audios y generar retroalimentación personalizada.
        * **Generación de contenido personalizado:** construir mensajes y resúmenes de check-in adaptados al progreso individual del participante.
        * **Seguimiento del programa:** registrar el avance por día, detectar ventanas de check-in y avanzar la fase del programa.
        * **Administración interna:** gestión del panel de operaciones por parte del equipo de Comtraining.
        * **Reportes para empresas:** proveer a las organizaciones patrocinadoras un análisis consolidado y anónimo de adherencia y barreras operacionales detectadas, garantizando la confidencialidad individual.

        No utilizamos sus datos para fines publicitarios, ni los vendemos, cedemos ni arrendamos a terceros con fines comerciales propios.

        #### 4. Compartición de datos y transferencias internacionales
        Para prestar el servicio utilizamos las siguientes plataformas externas, con las cuales sus datos pueden ser compartidos:

        **4.1 OpenAI, Inc. (Estados Unidos)**
        Los mensajes que usted envía son procesados por los modelos de lenguaje de OpenAI (como gpt-4o-mini o equivalentes) para la generación de respuestas personalizadas y análisis de audios. Esto implica una transferencia internacional de datos hacia servidores ubicados en Estados Unidos. OpenAI trata estos datos conforme a los términos de uso de su API, que prohíben el entrenamiento de modelos con datos de clientes.

        **4.2 Meta Platforms (WhatsApp Cloud API)**
        La comunicación con los participantes se realiza a través de WhatsApp Cloud API, operada por Meta Platforms, Inc. (EE. UU.) y Meta Platforms Ireland Limited (UE/EEE). Meta procesa metadatos de mensajería conforme a su Política de privacidad de WhatsApp Business.

        Ninguno de estos proveedores tiene autorización para usar sus datos con fines distintos a la prestación del servicio contratado.

        #### 5. Plazo de conservación de los datos
        Los datos personales se conservan mientras el participante esté activo en el programa y por un período adicional de **12 meses** tras la finalización, con el fin de atender eventuales consultas, repeticiones de programa o auditorías de servicio. Transcurrido ese plazo, los datos de las conversaciones se eliminan o anonimizan de nuestra base de datos.

        #### 6. Derechos del titular
        De conformidad con la **Ley N.° 19.628**, usted tiene los siguientes derechos respecto de sus datos personales:
        * **Acceso:** solicitar información sobre qué datos suyos tratamos y con qué finalidad.
        * **Rectificación:** solicitar la corrección de datos inexactos o desactualizados.
        * **Cancelación (eliminación):** solicitar la supresión de sus datos cuando ya no sean necesarios para la finalidad para la que fueron recopilados.
        * **Oposición:** oponerse al tratamiento de sus datos en determinadas circunstancias.

        Para ejercer cualquiera de estos derechos, escríbanos al correo indicado en la sección 9. Responderemos a su solicitud en un plazo no superior a 30 días hábiles.

        #### 7. Seguridad de los datos
        Comtraining adopta medidas técnicas y organizativas para proteger sus datos personales frente a accesos no autorizados, pérdida o divulgación indebida:
        * Acceso al panel de administración protegido con credenciales de administrador individuales.
        * Verificación criptográfica (HMAC-SHA256) de cada mensaje entrante de WhatsApp para prevenir suplantación.
        * Base de datos alojada en entorno con credenciales separadas por entorno y comunicación segura.
        * Claves de API almacenadas como variables de entorno seguras.

        #### 8. Cambios a esta política
        Podemos actualizar esta Política de Privacidad para reflejar cambios en el servicio, en la legislación aplicable o en nuestras prácticas internas. Cuando realicemos cambios materiales, se lo notificaremos a través de WhatsApp o por correo electrónico con al menos **15 días de anticipación**.

        #### 9. Contacto
        Para ejercer sus derechos, realizar consultas o presentar reclamos relacionados con el tratamiento de sus datos personales, puede contactarnos en:

        **Comtraining**
        Correo electrónico: [info@comtraining.cl](mailto:info@comtraining.cl)
        País: Chile
      TEXT
      description: "Texto completo de la Política de Privacidad de Impulso (Markdown)."
    },

    # ── finances ───────────────────────────────────────────────────────────
    "cost_hosting_monthly_usd" => {
      type: :float, category: "finances", default: 0.0,
      description: "Costo mensual de hosting/servidor en USD.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "cost_email_monthly_usd" => {
      type: :float, category: "finances", default: 0.0,
      description: "Costo mensual de envío de correos (Postmark, SendGrid, etc.) en USD.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "cost_meta_api_monthly_usd" => {
      type: :float, category: "finances", default: 0.0,
      description: "Costo mensual estimado de Meta/WhatsApp Cloud API (conversaciones de negocio) en USD.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "cost_ads_monthly_usd" => {
      type: :float, category: "finances", default: 0.0,
      description: "Gasto mensual en publicidad (Meta Ads, Google Ads, etc.) en USD.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "cost_other_monthly_usd" => {
      type: :float, category: "finances", default: 0.0,
      description: "Otros costos mensuales fijos en USD (dominio, herramientas, etc.).",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },

    # ── pagos (Webpay / Transbank) ───────────────────────────────────────────
    "webpay_enabled" => {
      type: :boolean, category: "finances", default: false,
      description: "Kill-switch de pagos: si es false, Webpay::Client no inicia transacciones."
    },
    "webpay_environment" => {
      type: :string, category: "finances", default: "integration",
      description: "Ambiente Transbank: integration (credenciales de prueba del SDK) o production (usa WEBPAY_COMMERCE_CODE/WEBPAY_API_KEY).",
      validate: ->(v) { %w[integration production].include?(v.to_s) || "debe ser integration o production" }
    },
    "membership_price_clp" => {
      type: :integer, category: "finances", default: 0,
      description: "Precio de la membresía individual en CLP (con IVA incluido). 0 = no se cobra.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "payment_commission_rate" => {
      type: :float, category: "finances", default: 0.0149,
      description: "Comisión de Transbank sobre el monto bruto (ej. 0.0149 = 1,49%).",
      validate: ->(v) { (0.0..1.0).cover?(v) || "debe estar entre 0.0 y 1.0" }
    },
    "tax_rate" => {
      type: :float, category: "finances", default: 0.19,
      description: "Tasa de IVA (Chile 19% = 0.19). Se usa para desglosar IVA débito de los ingresos y el IVA de la comisión.",
      validate: ->(v) { (0.0..1.0).cover?(v) || "debe estar entre 0.0 y 1.0" }
    },
    "usd_clp_rate" => {
      type: :float, category: "finances", default: 950.0,
      description: "Tipo de cambio USD→CLP usado en el P&L consolidado (/admin/resultado) para convertir los costos en USD a CLP. Actualízalo manualmente.",
      validate: ->(v) { v > 0 || "debe ser > 0" }
    },

    # ── capacidad / ops ──────────────────────────────────────────────────────
    "capacity_queue_latency_alert_seconds" => {
      type: :integer, category: "admin", default: 120,
      description: "Latencia (segundos) de una cola Sidekiq que dispara alerta a Sentry en CapacityAlertJob. 0 = desactivado.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "capacity_backlog_alert_threshold" => {
      type: :integer, category: "admin", default: 1000,
      description: "Backlog total (encolados + reintentos) que dispara alerta a Sentry en CapacityAlertJob. 0 = desactivado.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "coach_session_reminder_lead_hours" => {
      type: :integer, category: "program", default: 24,
      description: "Horas de antelación con que CoachSessionReminderJob envía el recordatorio WhatsApp de una sesión 1-1 confirmada. 0 = no enviar recordatorios.",
      validate: ->(v) { (0..168).cover?(v) || "debe estar entre 0 y 168" }
    },

    # ── suscripciones (Webpay Oneclick) ──────────────────────────────────────
    "webpay_oneclick_enabled" => {
      type: :boolean, category: "finances", default: false,
      description: "Kill-switch de suscripciones recurrentes (Webpay Oneclick). Si es false, no se inician inscripciones ni se cobran suscripciones."
    },
    "subscription_price_clp" => {
      type: :integer, category: "finances", default: 0,
      description: "Monto recurrente de la suscripción en CLP (IVA incluido). 0 = sin suscripción.",
      validate: ->(v) { v >= 0 || "debe ser >= 0" }
    },
    "subscription_billing_interval_days" => {
      type: :integer, category: "finances", default: 30,
      description: "Días entre cobros recurrentes de una suscripción Oneclick.",
      validate: ->(v) { (1..365).cover?(v) || "debe estar entre 1 y 365" }
    },
    "subscription_max_retries" => {
      type: :integer, category: "finances", default: 3,
      description: "Reintentos de cobro recurrente antes de marcar la suscripción como past_due.",
      validate: ->(v) { (0..10).cover?(v) || "debe estar entre 0 y 10" }
    },

    # ── copilot (ops copilot superadmin) ─────────────────────────────────────
    "copilot_enabled" => {
      type: :boolean, category: "copilot", default: false,
      description: "Kill-switch del copiloto de operaciones (/admin/copilot). Off = el agente no corre. Solo superadmins. Default OFF."
    },
    "copilot_action_cap_per_session" => {
      type: :integer, category: "copilot", default: 10,
      description: "Máximo de acciones (act tools) que el copiloto puede proponer por sesión. Frena loops/abuso por inyección.",
      validate: ->(v) { (1..100).cover?(v) || "debe estar entre 1 y 100" }
    },
    "copilot_token_budget_per_session" => {
      type: :integer, category: "copilot", default: 200_000,
      description: "Presupuesto de tokens (input+output) por sesión del copiloto. Al superarlo, el loop se detiene.",
      validate: ->(v) { v >= 1_000 || "debe ser >= 1000" }
    },

    # ── program assistant (chat IA para crear/editar programas) ──────────────
    "program_assistant_enabled" => {
      type: :boolean, category: "program", default: true,
      description: "Kill-switch del Asistente IA de programas (modal en /admin/programs). Off = el agente no corre."
    },
    "program_assistant_action_cap_per_session" => {
      type: :integer, category: "program", default: 15,
      description: "Máximo de acciones (crear/editar programa) que el asistente puede proponer por sesión.",
      validate: ->(v) { (1..100).cover?(v) || "debe estar entre 1 y 100" }
    },
    "program_assistant_token_budget_per_session" => {
      type: :integer, category: "program", default: 400_000,
      description: "Presupuesto de tokens (input+output) por sesión del asistente de programas. Al superarlo, el loop se detiene.",
      validate: ->(v) { v >= 1_000 || "debe ser >= 1000" }
    }
  }.freeze

  validates :key,        presence: true, uniqueness: true
  validates :value_type, inclusion: { in: VALUE_TYPES }
  validates :category,   inclusion: { in: CATEGORIES }
  validate  :value_passes_schema_validation

  after_commit :clear_cache

  # Typed read. Reads cache → DB → schema default.
  def self.fetch(key)
    key = key.to_s
    Rails.cache.fetch("#{CACHE_PREFIX}#{key}", expires_in: CACHE_TTL) do
      record = find_by(key: key)
      if record
        cast(record.value, record.value_type)
      elsif (schema = SCHEMA[key])
        schema[:default]
      end
    end
  end

  # Legacy string-only accessor. Prefer .fetch for new code.
  def self.get(key)
    value = fetch(key)
    value.nil? ? nil : value.to_s
  end

  def self.set(key, value)
    schema = SCHEMA[key.to_s] || {}
    record = find_or_initialize_by(key: key.to_s)
    record.value_type    = (schema[:type] || :string).to_s
    record.category      = schema[:category] || "general"
    record.description ||= schema[:description]
    record.value = serialize(value, record.value_type)
    record.save!
    record
  end

  # Idempotent. Seeds any SCHEMA entry not yet persisted.
  def self.seed_defaults!
    SCHEMA.each do |key, spec|
      next if exists?(key: key)
      create!(
        key:         key,
        value:       serialize(spec[:default], spec[:type].to_s),
        value_type:  spec[:type].to_s,
        category:    spec[:category],
        description: spec[:description]
      )
    end
  end

  def self.cast(raw, type)
    return nil if raw.nil?
    case type.to_s
    when "integer" then raw.to_i
    when "float"   then raw.to_f
    when "boolean" then ActiveModel::Type::Boolean.new.cast(raw)
    when "json"    then JSON.parse(raw) rescue nil
    else                raw.to_s
    end
  end

  def self.serialize(value, type)
    return nil if value.nil?
    case type.to_s
    when "json" then value.is_a?(String) ? value : value.to_json
    else             value.to_s
    end
  end

  def typed_value
    self.class.cast(value, value_type)
  end

  def schema_entry
    SCHEMA[key]
  end

  private

  def value_passes_schema_validation
    entry = SCHEMA[key]
    return unless entry && entry[:validate]
    casted = self.class.cast(value, value_type)
    result = entry[:validate].call(casted)
    errors.add(:value, result) if result.is_a?(String)
  end

  def clear_cache
    Rails.cache.delete("#{CACHE_PREFIX}#{key}")
  end
end
