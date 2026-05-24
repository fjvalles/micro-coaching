# Arquitectura Técnica y Flujos de la Plataforma

Esta guía describe la arquitectura de software, los flujos de datos asincrónicos, los sistemas de mensajería y la integración de IA.

---

## 1. Arquitectura de Alto Nivel

La aplicación está construida como una aplicación monolítica Rails 7.2 con una base de datos PostgreSQL 16 y una cola de tareas asincrónicas en Redis 7 gestionada por Sidekiq.

```mermaid
graph LR
    classDef meta fill:#dfebd6,stroke:#25d366,stroke-width:2px,color:#128c7e;
    classDef app fill:#e0e7ff,stroke:#6366f1,stroke-width:2px,color:#4338ca;
    classDef db fill:#f1f5f9,stroke:#64748b,stroke-width:2px,color:#334155;
    classDef ai fill:#fae8ff,stroke:#d946ef,stroke-width:2px,color:#86198f;

    Meta[Meta Cloud API]:::meta
    OpenAI[OpenAI API]:::ai

    subgraph RailsApp ["Aplicación Rails 7.2"]
        Webhook[WebhooksController]:::app
        Jobs[Sidekiq Workers]:::app
        DB[(PostgreSQL)]:::db
        Redis[(Redis 7)]:::db
    end

    Meta -- Webhook Inbound --> Webhook
    Webhook -- Encola Tarea --> Redis
    Redis -- Levanta --> Jobs
    Jobs -- Consulta / Guarda --> DB
    Jobs -- Genera Prompts --> OpenAI
    Jobs -- WhatsApp Outbound --> Meta
```

---

## 2. Flujo de Procesamiento del Webhook de WhatsApp

Cuando un participante interactúa por WhatsApp, Meta envía una solicitud POST HTTP a nuestro endpoint. Este flujo debe ser ultra-rápido y asincrónico para cumplir con el timeout de 5 segundos de Meta.

```mermaid
sequenceDiagram
    autonumber
    participant Meta as Meta API
    participant Controller as WebhooksController
    participant Verifier as SignatureVerifier
    participant Redis as Redis Queue
    participant Job as ProcessIncomingMessageJob
    participant DB as PostgreSQL
    participant Classifier as MessageClassifier
    participant Summarizer as CheckinSummarizer
    participant Client as Whatsapp::Client

    Meta->>Controller: POST /webhooks/whatsapp (payload + X-Hub-Signature-256)
    Controller->>Verifier: verify(payload, signature)
    alt Firma inválida
        Verifier-->>Controller: false
        Controller-->>Meta: 401 Unauthorized
    else Firma válida
        Verifier-->>Controller: true
        Controller->>Redis: Encolar ProcessIncomingMessageJob(payload)
        Controller-->>Meta: 200 OK (Retorno inmediato < 1s)
    end

    Note over Job: Sidekiq procesa en background
    Redis->>Job: Ejecuta Job
    Job->>Job: Valida tipo "text" (rechaza audios/imágenes)
    Job->>DB: Persiste mensaje temporal como :free_user

    Job->>Classifier: classify(participant, message)
    alt Es respuesta al Welcome
        Classifier-->>Job: :initial_pattern_answer
        Job->>DB: Guarda initial_pattern, actualiza a :welcome
        Job->>Client: send_text (Agradecimiento)
    else Es respuesta al Check-in nocturno
        Classifier-->>Job: :checkin_response
        Job->>DB: Actualiza momento a :checkin_response
        Job->>Summarizer: call(conversation_history)
        Note over Summarizer: Llama a OpenAI (temp: 0.3)
        Summarizer-->>Job: { summary, key_pattern }
        Job->>DB: Crea DailyReport
        Job->>Client: send_text (Cierre del día)
    else Es pregunta libre del usuario
        Classifier-->>Job: :free_user
        Job->>DB: Mantiene como :free_user
        Note over Job: Llama a FreeResponseGenerator
        Job->>Client: send_text (Respuesta libre IA)
    end
```

---

## 3. Cadencia y Cron Jobs Diarios

Los procesos repetitivos están programados mediante `sidekiq-cron` en el archivo `config/schedule.yml`.

```mermaid
flowchart TD
    A["☀️  07:00 — MorningWakeJob\nEnvía mensaje de inicio del día personalizado"]
    B["🎯  07:30 — SendIaretoJob\nEnvía el reto conductual de la mañana"]
    C["🌙  20:00 — CheckinEveningJob\nEnvía preguntas de reflexión nocturna"]
    D["⏳  20:00 – 23:59\nVentana activa de respuesta del participante"]
    E["🔄  06:00 UTC — AdvanceDayJob\nAvance global de día para todos los participantes"]

    A --> B --> C --> D --> E
```

### 3.1 Avance de Día (`AdvanceDayJob`)
Este job corre globalmente a las **06:00 UTC** diariamente. Llama a `Participants::DayAdvancer`, el cual realiza las siguientes validaciones para cada participante activo:

1. **Verificación de Check-in:** Busca si el participante tiene un mensaje con `moment: :checkin_response` y `day_number: current_day` creado en el día de hoy en su zona horaria.
2. **Avance:** Si respondió, incrementa `current_day` en 1.
3. **Cierre:** Si ya completó el día 14 e hizo check-in, cambia el estado a `:completed`, estampa `completed_at` y encola el `GenerateAndSendManifestoJob` para el día 15.
4. **Sin re-engagement:** Si no respondió el check-in, el participante se queda congelado en su día actual. Ningún mensaje del día actual se reenvía para evitar spam, pero tampoco avanza de día hasta que complete el reto pendiente.

---

## 4. Salvaguardas y Reglas Críticas del Negocio

### 4.1 La Ventana de 24 Horas de Meta (Free-form vs Templates)
Por políticas comerciales de WhatsApp, solo se pueden enviar mensajes de texto libre (free-form) si el participante ha enviado un mensaje en las últimas 24 horas (`in_24h_window?`). 

* **Si está dentro de la ventana:** Podemos enviar texto libre generado dinámicamente por la IA.
* **Si está fuera de la ventana:** Estamos obligados a usar una plantilla (Template) pre-aprobada por Meta. Si intentamos enviar un texto libre, Meta rechazará el mensaje, lo que puede resultar en suspensiones de cuenta.
* **En el código:** `SendIaretoJob` y `CheckinForParticipantJob` evalúan `participant.in_24h_window?`. Si es falso, llaman a `Whatsapp::TemplateSender` en lugar de enviar el texto de la IA directamente.

### 4.2 Idempotencia de Tareas
Para evitar el reenvío de mensajes duplicados en caso de reintentos automáticos de Sidekiq por fallas de conexión:

```ruby
# Verificación de idempotencia en MorningWakeForParticipantJob
return if Participant.conversations.where(
  moment: :morning_wake, 
  day_number: current_day, 
  created_at: Time.current.all_day
).exists?
```
Cada job de envío verifica la existencia de un registro de `Conversation` en la base de datos para ese `moment` y `day_number` antes de proceder.

---

## 5. Diseño y Costos de IA (Prompt Caching)

El costo de la API de OpenAI está dominado principalmente por la cantidad de tokens enviados en el prompt del sistema (contexto). Para mitigar esto, implementamos **Prompt Caching** obligatorio:

> [!IMPORTANT]
> **Prompt Caching en OpenAI:**
> OpenAI proporciona un descuento de hasta el 50% de descuento en tokens de entrada y reduce la latencia cuando el prompt del sistema reutiliza los mismos bloques iniciales de texto. 
> Para aprovechar esto, todo generador de IA (`MorningMessageGenerator`, `FreeResponseGenerator`, `CheckinSummarizer`) debe concatenar `Openai::ProgramManifesto::TEXT` al inicio de su prompt del sistema. Este manifiesto común pesa ~1,200 tokens, lo que garantiza que califique para el caché automático de OpenAI (requiere >1,024 tokens compartidos).
