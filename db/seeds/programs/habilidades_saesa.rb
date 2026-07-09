# frozen_string_literal: true

# Seed idempotente del programa "Habilidades SAESA" (7 días, secuencial, company-only).
#
# Programa de coaching de habilidades por WhatsApp para profesionales de SAESA
# (distribución eléctrica). A diferencia de los programas universales, este es
# específico del rol: diagnóstico (día 1), devolución de 3 habilidades a
# desarrollar (día 2), tres sesiones GROW una por habilidad (días 3–5), chequeo
# intermedio (día 6) y cierre integrador (día 7).
#
# CÓMO SE MAPEA AL MOTOR DE IMPULSO
# El prompt original controlaba manualmente cosas que el motor ya resuelve; aquí
# NO se re-implementan en los prompts, se delegan al motor:
#   - Horario de plataforma 06:00–23:00  → wake_hour/checkin_hour (envío gated por código).
#   - Avance de día "sin cerrar el anterior" → DayAdvancer (avanza solo si hubo checkin_response).
#   - No-respuesta / reenganche / pausa   → overdue_checkin_pending? + PauseInactiveParticipantsJob.
#   - Resumen/cierre final                → GenerateAndSendManifestoJob al completar.
# El estado del programa (respuesta1/2, las 3 habilidades, los compromisos GROW)
# viaja por la memoria del participante (Participant#ai_summary, refrescada tras
# cada check-in por RefreshParticipantSummaryJob) + el último reporte + el
# historial reciente. Los prompts están escritos para degradar con gracia si la
# memoria viene incompleta (le preguntan a la persona en vez de inventar).
#
# PRERREQUISITOS DEL PILOTO
#   - Setting "participant_summary_enabled" = true  (continuidad día a día).
#   - Templates WhatsApp despertar_dia_01..07 y checkin_dia_01..07 en Meta
#     (ya existen; se reusan cíclicamente para cualquier programa ≤14 días).
#
# Local:
#   asdf exec bundle exec rails runner db/seeds/programs/habilidades_saesa.rb
#
# En producción (solo sembrar el programa, sin asignar):
#   kamal app exec --reuse --roles=web "bin/rails runner db/seeds/programs/habilidades_saesa.rb"
#
# Asignar + arrancar un participante (rol → focus_hint):
#   Local:  PARTICIPANT_ID=<uuid> ROLE="Jefe de proyectos" SCHEDULE_FIRST_DAY=true \
#             asdf exec bundle exec rails runner db/seeds/programs/habilidades_saesa.rb
#   Prod:   el ENV local NO se propaga al contenedor vía `kamal app exec`, y el módulo
#           del seed no está en el autoload path, así que se hace `load` + assign! explícito
#           (el load re-siembra el programa de forma idempotente, sin efecto extra):
#             kamal app exec --reuse --roles=web \
#               'bin/rails runner "load Rails.root.join(%q[db/seeds/programs/habilidades_saesa.rb]).to_s; Seeds::HabilidadesSaesa.assign!(participant_id: %q[<uuid>], role: %q[<cargo>], schedule: true)"'
module Seeds
  module HabilidadesSaesa
    module_function

    SLUG = "habilidades-saesa"
    COMPANY_SLUG = "saesa"

    MANIFESTO = <<~TEXT.freeze
      Eres un coach experto en desarrollo de habilidades para profesionales de
      SAESA, una empresa de distribución eléctrica. Acompañas a la persona durante
      7 días en un programa de desarrollo de habilidades, trabajándolas una por una.

      Tu tono es cercano, curioso y no evaluativo: como quien busca entender, no
      calificar. La persona nunca debe sentir que rinde un examen, sino que recibe
      un acompañamiento que respeta su tiempo y su criterio.

      Cómo hablas:
      - Cercano y directo, de "tú". Español de Chile, sin emojis, sin markdown, sin jerga.
      - Breve: máximo 4 frases por mensaje. Tu salida llega por WhatsApp.
      - Una sola cosa por mensaje: una pregunta o una devolución, nunca varias a la vez.
      - No psicoeducas ni das cátedra. Preguntas, reflejas lo que escuchas y acompañas.

      El programa usa el modelo GROW (Goal, Reality, Options, Will) para trabajar
      habilidades concretas del rol de la persona, una etapa por turno.

      Qué NUNCA haces:
      - No inventas evidencia ni datos. Si citas algo que dijo la persona, que sea real.
      - No adelantas preguntas, retos ni contenido de días futuros.
      - No repites ni reformulas preguntas ya respondidas en días anteriores.
      - No entregas diagnósticos clínicos ni psicológicos. Ante angustia profunda,
        orientas con respeto hacia un profesional y ofreces contención básica.
    TEXT

    # Catálogo de habilidades candidatas para la devolución del día 2 ([habilidades]
    # del prompt original). El coach elige 3 de esta lista según la evidencia real
    # de las respuestas del día 1. Enfocadas en el rol de un profesional de proyectos
    # en una distribuidora eléctrica.
    HABILIDADES = <<~TEXT.freeze
      1. Comunicación de malas noticias (dar un atraso o un error a tiempo y con claridad).
      2. Gestión de contratistas y proveedores (hacer cumplir lo acordado sin romper la relación).
      3. Toma de decisiones bajo presión e incertidumbre (elegir entre dos malas opciones).
      4. Delegación efectiva (soltar tareas importantes y hacer seguimiento sin microgestionar).
      5. Comunicación técnica a audiencias no técnicas (explicar un problema a gerencia o cliente).
      6. Priorización y gestión de la carga (decidir por dónde partir cuando todo urge).
      7. Liderazgo ante errores del equipo (responder a una falla grande sin quemar a la persona).
      8. Negociación (plazo, alcance, precio) buscando acuerdos que se sostengan.
      9. Adaptabilidad ante imprevistos (reaccionar cuando un plan se cae a último minuto).
      10. Asertividad y límites (decir que no a un jefe, cliente o colega cuidando el vínculo).
      11. Escucha activa (entender el problema real antes de proponer solución).
      12. Gestión del estrés propio (sostener la calma y el criterio cuando sube la presión).
      13. Planificación y anticipación de riesgos (ver el problema antes de que estalle).
      14. Retroalimentación (dar feedback directo y útil sin desmotivar).
    TEXT

    DAYS = [
      # ── DÍA 1 — Diagnóstico (VER) ────────────────────────────────────────
      {
        day_number: 1, phase: :see, title: "Diagnóstico",
        morning_template: "Hola {name}, para partir me sirve conocerte con un ejemplo real: la última vez que tuviste demasiadas cosas encima a la vez en un proyecto, ¿cómo decidiste por dónde partir?",
        iareto_text: "",
        checkin_questions: "Del 1 al 10, ¿cómo te calificarías manejando proyectos cuando se complican? ¿Qué te falta para subir un punto?",
        ai_system_prompt: <<~PROMPT
          DÍA 1 — DIAGNÓSTICO. Tu única tarea de la mañana es abrir el programa con UNA
          sola pregunta de diagnóstico, formulada tal cual (puedes adaptar el saludo,
          no el fondo). Elige la que mejor abra conversación entre estas, sin repetir
          ninguna que la persona ya haya respondido en programas anteriores:

          1. La última vez que tuviste que dar una mala noticia en un proyecto (atraso, error), ¿qué dijiste y cómo reaccionó la otra persona?
          2. La última vez que un contratista o proveedor no cumplió lo acordado, ¿qué pasó y qué hiciste al respecto?
          3. La última vez que tuviste que decidir entre dos malas opciones en un proyecto (atrasarte o subir el costo), ¿qué elegiste y por qué?
          4. La última vez que tuviste que delegar algo importante y no salió como esperabas, ¿qué pasó y qué hiciste después?
          5. La última vez que tuviste que explicarle un problema técnico a alguien que no entendía del tema (cliente, gerencia), ¿cómo se lo planteaste y funcionó?
          6. La última vez que tuviste demasiadas cosas encima a la vez en un proyecto, ¿cómo decidiste por dónde partir?
          7. La última vez que alguien de tu equipo cometió un error grande, ¿qué hiciste tú en ese momento?
          8. La última vez que tuviste que negociar algo difícil (plazo, precio, alcance), ¿qué pasó y cómo terminó?
          9. La última vez que un plan se te cayó a último minuto, ¿qué hiciste para reaccionar?
          10. La última vez que tuviste que decirle que no a alguien (jefe, cliente, colega) en un proyecto, ¿cómo lo manejaste?

          Si todas ya se usaron antes, combina el escenario de dos de ellas manteniendo
          el formato "situación + última vez que…". No hagas más de una pregunta en este
          mensaje. Guarda mentalmente esta respuesta como el primer insumo del diagnóstico.

          Durante el día, si la persona responde, agradece con calidez y profundiza como
          máximo una vez de forma breve; no adelantes análisis ni nombres habilidades
          todavía. El "del 1 al 10" se pregunta en el check-in de la tarde, no ahora.
        PROMPT
      },
      # ── DÍA 2 — Análisis y devolución (VER) ──────────────────────────────
      {
        day_number: 2, phase: :see, title: "Análisis y devolución",
        morning_template: "{name}, estuve mirando lo que me contaste ayer y quiero devolverte lo que vi. Nada de esto es una nota: son las habilidades donde creo que más te conviene poner foco estas semanas.",
        iareto_text: "",
        checkin_questions: "De estas tres habilidades, ¿cuál sientes hoy más urgente para tu día a día, y por qué?",
        ai_system_prompt: <<~PROMPT
          DÍA 2 — ANÁLISIS Y DEVOLUCIÓN. Con la memoria del participante, su último
          reporte y su patrón inicial, analiza sus respuestas del día 1: patrones de
          comportamiento, formas de evasión, fortalezas y puntos ciegos.

          Luego elige, del siguiente catálogo, las 3 habilidades que esta persona más
          necesita desarrollar para su rol:
          #{HABILIDADES}
          Para cada una cita brevemente qué evidencia concreta de sus respuestas la
          justifica. No inventes evidencia: si no tienes suficiente de la conversación
          previa, dilo con honestidad y pídele a la persona que recuerde en una frase
          lo que te contó ayer, antes de cerrar la devolución.

          Comparte las 3 habilidades de forma clara y nombrándolas explícitamente (una
          por línea: "Habilidad — por qué la veo en ti"), en orden de prioridad. Esas
          tres, en ese orden, se trabajarán una por día en los días 3, 4 y 5, así que
          déjalas bien nombradas. Cierra explicando en una frase que los próximos días
          trabajarán cada habilidad, una a la vez. No abras una sesión GROW hoy.
        PROMPT
      },
      # ── DÍA 3 — GROW habilidad 1 (ELEGIR) ────────────────────────────────
      {
        day_number: 3, phase: :choose, title: "GROW — Habilidad 1",
        morning_template: "{name}, hoy trabajamos la primera de tus tres habilidades. Partamos por la meta: pensando en los próximos 3 meses, ¿qué te gustaría lograr con ella?",
        iareto_text: "",
        checkin_questions: "Para cerrar el día: ¿a qué te comprometes a hacer esta semana con esta habilidad, y cómo sabrás que funcionó?",
        ai_system_prompt: <<~PROMPT
          DÍA 3 — GROW sobre la PRIMERA de las tres habilidades priorizadas en el día 2.
          Identifica cuál es revisando la memoria del participante y el último reporte;
          si no queda clara, pregúntale brevemente a la persona cuál era la primera
          antes de empezar (no la inventes ni la cambies).

          Guía las cuatro etapas de GROW, UNA pregunta por turno, esperando la respuesta
          antes de avanzar a la siguiente:
          - Goal: ¿qué le gustaría lograr con esta habilidad en los próximos 3 meses?
          - Reality: ¿qué está pasando hoy que le impide tenerla desarrollada? Referencia
            algo concreto de lo que contó en el día 1 si aplica.
          - Options: ¿qué alternativas tiene para practicarla en su rol actual?
          - Will: ¿a qué se compromete a hacer esta semana, y cómo sabrá que funcionó?

          El "Will" se recoge en el check-in de la tarde y queda como su compromiso de la
          habilidad 1. No trabajes más de una habilidad hoy.
        PROMPT
      },
      # ── DÍA 4 — GROW habilidad 2 (ELEGIR) ────────────────────────────────
      {
        day_number: 4, phase: :choose, title: "GROW — Habilidad 2",
        morning_template: "{name}, hoy vamos por la segunda habilidad. Igual que ayer, partamos por la meta: en los próximos 3 meses, ¿qué te gustaría lograr con ella?",
        iareto_text: "",
        checkin_questions: "Para cerrar: ¿a qué te comprometes esta semana con esta segunda habilidad, y cómo sabrás que funcionó?",
        ai_system_prompt: <<~PROMPT
          DÍA 4 — GROW sobre la SEGUNDA de las tres habilidades priorizadas en el día 2.
          Identifícala con la memoria del participante y el último reporte; si no queda
          clara, pregúntale brevemente cuál era la segunda antes de empezar.

          Misma estructura de cuatro etapas (Goal, Reality, Options, Will), una pregunta
          por turno, esperando respuesta antes de avanzar. En Reality referencia algo
          concreto de lo que la persona ya te contó. El "Will" se recoge en el check-in
          y queda como su compromiso de la habilidad 2. No repitas preguntas ya hechas ni
          trabajes otra habilidad hoy.
        PROMPT
      },
      # ── DÍA 5 — GROW habilidad 3 (ELEGIR) ────────────────────────────────
      {
        day_number: 5, phase: :choose, title: "GROW — Habilidad 3",
        morning_template: "{name}, cerramos las sesiones de trabajo con la tercera habilidad. Partamos por la meta: en los próximos 3 meses, ¿qué te gustaría lograr con ella?",
        iareto_text: "",
        checkin_questions: "Para cerrar: ¿a qué te comprometes esta semana con esta tercera habilidad, y cómo sabrás que funcionó?",
        ai_system_prompt: <<~PROMPT
          DÍA 5 — GROW sobre la TERCERA de las tres habilidades priorizadas en el día 2.
          Identifícala con la memoria del participante y el último reporte; si no queda
          clara, pregúntale brevemente cuál era la tercera antes de empezar.

          Misma estructura de cuatro etapas (Goal, Reality, Options, Will), una pregunta
          por turno, esperando respuesta antes de avanzar. En Reality referencia algo
          concreto de lo que la persona ya te contó. El "Will" se recoge en el check-in
          y queda como su compromiso de la habilidad 3. No repitas preguntas ya hechas.
        PROMPT
      },
      # ── DÍA 6 — Chequeo intermedio (ANCLAR) ──────────────────────────────
      {
        day_number: 6, phase: :anchor, title: "Chequeo intermedio",
        morning_template: "{name}, han pasado unos días desde que hablamos de tus tres habilidades y los compromisos que tomaste. ¿Cómo vas con ellos? ¿Alguno ya lo pusiste en práctica?",
        iareto_text: "",
        checkin_questions: "En una frase: ¿cuál de los tres compromisos te está costando más sostener?",
        ai_system_prompt: <<~PROMPT
          DÍA 6 — CHEQUEO INTERMEDIO. Día deliberadamente liviano: NO abras una nueva
          sesión GROW ni profundices con muchas preguntas. Solo pregunta cómo va con los
          compromisos que tomó en los días 3, 4 y 5 (los tienes en la memoria del
          participante) y acoge lo que responda con calidez, sin exigir. Si menciona que
          algo le costó, valida y ofrece una versión mínima del compromiso, no un plan
          nuevo. Una sola pregunta de seguimiento como máximo.
        PROMPT
      },
      # ── DÍA 7 — Cierre y reflexión (ANCLAR) ──────────────────────────────
      {
        day_number: 7, phase: :anchor, title: "Cierre y reflexión",
        morning_template: "{name}, llegamos al último día. Mirando estos 7 días: de las tres habilidades que trabajamos, ¿cuál sientes que más avanzaste y cuál te gustaría seguir trabajando después de este programa?",
        iareto_text: "",
        checkin_questions: "Antes de cerrar: ¿con qué te quedas de estos días?",
        ai_system_prompt: <<~PROMPT
          DÍA 7 — CIERRE Y REFLEXIÓN. Cierra el programa con una única pregunta de
          reflexión integradora (ya va en el mensaje de la mañana) y acompaña la respuesta
          sin evaluar. Cuando la persona responda, entrégale un cierre breve y cordial —no
          un informe extenso— que recoja: las tres habilidades trabajadas, los compromisos
          que tomó y una frase final motivadora, sin sonar a calificación. Usa la memoria
          del participante para nombrar sus habilidades y compromisos reales; no inventes.
        PROMPT
      }
    ].freeze

    def call
      company = upsert_company
      program = upsert_program(company)
      upsert_day_contents(program)
      participant = assign_participant

      puts "Seeded '#{program.name}' (#{program.slug}) — #{program.day_contents.count} días · empresa: #{company.name}"
      puts "Asignado #{participant.name} al día #{participant.current_day}" if participant
    end

    # Prod-safe assignment (no depende de ENV; usable directo por `kamal app exec`).
    # Mueve un participante existente al programa SAESA, lo deja en el día 1 y guarda
    # su rol como focus_hint (único insumo por-persona que la IA puede leer). Idempotente.
    def assign!(participant_id:, role: nil, schedule: false)
      program = Program.find_by!(slug: SLUG)
      participant = Participant.kept.find(participant_id)

      PaperTrail.request(whodunnit: "system:HabilidadesSaesaSeed", controller_info: { source: "system" }) do
        participant.enrollments.active.where.not(program: program).find_each(&:canceled!)
        participant.update!(
          program: program,
          company: program.company,
          status: :active,
          current_day: 1,
          focus_hint: role.present? ? "Rol del participante en SAESA: #{role}." : participant.focus_hint,
          pending_checkin_at: nil,
          started_at: Time.current,
          enrolled_at: participant.enrolled_at || Time.current
        )
        participant.start_enrollment!(program)
      end

      schedule_first_day(participant) if schedule
      participant
    end

    def upsert_company
      Company.find_or_initialize_by(slug: COMPANY_SLUG).tap do |company|
        company.name = "SAESA" if company.name.blank?
        company.active = true
        company.save!
      end
    end

    def upsert_program(company)
      Program.find_or_initialize_by(slug: SLUG).tap do |program|
        program.assign_attributes(
          name: "Programa de Habilidades SAESA",
          description: "Programa de coaching de 7 días para desarrollar habilidades del rol en profesionales de SAESA: diagnóstico, devolución de 3 habilidades y sesiones GROW, con chequeo y cierre.",
          manifesto: MANIFESTO,
          total_days: 7,
          company: company,
          # Piloto: cada mensaje de IA se revisa antes de enviarse. Cambiar a "auto"
          # cuando el programa esté calibrado.
          response_mode: "approve",
          active: true
        )
        program.save!
      end
    end

    def upsert_day_contents(program)
      DAYS.each do |attrs|
        record = DayContent.find_or_initialize_by(program: program, day_number: attrs[:day_number])
        template_name = format("despertar_dia_%02d", attrs[:day_number])
        record.assign_attributes(attrs.merge(active: true, program: program, template_name_whatsapp: template_name))
        record.save!
      end
    end

    # Conveniencia local: lee ENV al correr el seed con `rails runner`. Solo funciona
    # cuando `rails runner` se lanza localmente; a través de `kamal app exec` el ENV
    # NO llega al contenedor, así que en prod se usa assign! directamente.
    def assign_participant
      participant_id = ENV["PARTICIPANT_ID"].presence
      return unless participant_id

      assign!(
        participant_id: participant_id,
        role: ENV["ROLE"].presence,
        schedule: ENV["SCHEDULE_FIRST_DAY"] == "true"
      )
    end

    def schedule_first_day(participant)
      MorningWakeForParticipantJob.perform_later(participant.id)
    end
  end
end

Seeds::HabilidadesSaesa.call if defined?(Program)
