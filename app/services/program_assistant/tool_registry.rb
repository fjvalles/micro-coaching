module ProgramAssistant
  # The security boundary. A fixed catalog of tools the assistant may call.
  # Dispatch is ALWAYS a hash lookup by name — a model-supplied string never
  # reaches `send`/`eval`. Tools are one of two categories:
  #
  #   :read → executes immediately, returns structured data (no side effects).
  #   :act  → NEVER executes inline. The runner records a
  #           ProgramAssistantPendingAction and waits for admin approval before
  #           running ProgramAssistant::ActExecutor.
  class ToolRegistry
    Tool = Struct.new(
      :name, :category, :description, :parameters, :callable, :requires_confirmation,
      keyword_init: true
    )

    # A day spec shared by create_program and update_program schemas.
    DAY_SCHEMA = {
      type: "object",
      properties: {
        day_number: { type: "integer", description: "1..total_days, consecutivo desde 1, sin huecos" },
        phase: { type: "string", enum: %w[see choose anchor], description: "see=observar, choose=elegir distinto, anchor=consolidar" },
        title: { type: "string", description: "Foco corto del día" },
        morning_template: { type: "string", description: "Mensaje matinal (2-4 frases, segunda persona)" },
        iareto_text: { type: "string", description: "El micro-reto o invitación concreta del día (1-2 frases)" },
        checkin_questions: { type: "string", description: "1-3 preguntas de cierre separadas por saltos de línea" },
        ai_system_prompt: { type: "string", description: "Instrucciones para el coach IA ese día: tono, foco, qué reforzar" }
      },
      required: %w[day_number phase title],
      additionalProperties: false
    }.freeze

    # --- READ TOOLS (no side effects) ---------------------------------------
    READ_TOOLS = {
      "list_programs" => Tool.new(
        name: "list_programs", category: :read, requires_confirmation: false,
        description: "Lista los programas existentes (nombre, slug, días, estado). Úsalo para ubicar un programa antes de leerlo o editarlo.",
        parameters: {
          type: "object",
          properties: { only_active: { type: "boolean", description: "Si true, solo programas activos" } },
          required: [], additionalProperties: false
        },
        callable: ->(args) { ReadTools.list_programs(args) }
      ),
      "get_program" => Tool.new(
        name: "get_program", category: :read, requires_confirmation: false,
        description: "Devuelve un programa completo con todo su contenido día por día. Identifícalo por id (UUID) o por slug.",
        parameters: {
          type: "object",
          properties: {
            program_id: { type: "string", description: "id (UUID) del programa" },
            slug: { type: "string", description: "slug del programa (alternativa al id)" }
          },
          required: [], additionalProperties: false
        },
        callable: ->(args) { ReadTools.get_program(args) }
      )
    }.freeze

    # --- ACT TOOLS (gated; execute ONLY via ProgramAssistant::ActExecutor) ----
    # The callable raises by design: act tools must never run inline from the
    # agent loop. The loop records a pending action and stops; an admin approves,
    # and the controller runs ProgramAssistant::ActExecutor.
    act_callable = ->(_args) { raise "act tools execute only via ProgramAssistant::ActExecutor" }

    ACT_TOOLS = {
      "create_program" => Tool.new(
        name: "create_program", category: :act, requires_confirmation: true,
        description: "Propone CREAR un programa nuevo con todo su contenido día por día (requiere aprobación humana). Llama esto solo cuando ya tengas claro el objetivo, la duración y el arco del programa.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Nombre corto y motivador del programa" },
            description: { type: "string", description: "Descripción breve (1-2 frases) para el listado" },
            manifesto: { type: "string", description: "2-4 frases que enmarcan el propósito, en segunda persona" },
            total_days: { type: "integer", description: "Número total de días (debe igualar la cantidad de días enviados)" },
            days: { type: "array", items: DAY_SCHEMA, description: "Un objeto por día, day_number consecutivo desde 1" }
          },
          required: %w[name total_days days], additionalProperties: false
        },
        callable: act_callable
      ),
      "update_program" => Tool.new(
        name: "update_program", category: :act, requires_confirmation: true,
        description: "Propone EDITAR un programa existente (requiere aprobación humana). Puedes cambiar metadatos y/o insertar/actualizar días concretos por day_number (upsert). Identifica el programa por id o slug.",
        parameters: {
          type: "object",
          properties: {
            program_id: { type: "string", description: "id (UUID) del programa" },
            slug: { type: "string", description: "slug del programa (alternativa al id)" },
            name: { type: "string", description: "Nuevo nombre (opcional)" },
            description: { type: "string", description: "Nueva descripción (opcional)" },
            manifesto: { type: "string", description: "Nuevo manifiesto (opcional)" },
            total_days: { type: "integer", description: "Nuevo total de días (opcional)" },
            days: { type: "array", items: DAY_SCHEMA, description: "Días a insertar o actualizar (upsert por day_number). Omite los días que no cambian." }
          },
          required: [], additionalProperties: false
        },
        callable: act_callable
      )
    }.freeze

    ALL = READ_TOOLS.merge(ACT_TOOLS).freeze

    def self.fetch(name)
      ALL[name.to_s]
    end

    def self.read?(name)
      READ_TOOLS.key?(name.to_s)
    end

    def self.act?(name)
      ACT_TOOLS.key?(name.to_s)
    end

    # OpenAI function-calling tool schemas.
    def self.openai_schemas
      ALL.values.map do |tool|
        {
          type: "function",
          function: {
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters
          }
        }
      end
    end
  end
end
