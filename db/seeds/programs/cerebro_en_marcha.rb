# frozen_string_literal: true

# Idempotent seed for an 8-week cognitive-support program.
#
# Local:
#   asdf exec bundle exec rails runner db/seeds/programs/cerebro_en_marcha.rb
#
# Production assignment/scheduling:
#   PARTICIPANT_ID=<uuid> SCHEDULE_FIRST_DAY=true \
#     kamal app exec "bin/rails runner db/seeds/programs/cerebro_en_marcha.rb"

module Seeds
  class CerebroEnMarcha
    SLUG = "cerebro-en-marcha"

    MANIFESTO = <<~TEXT.squish
      Cerebro en Marcha es un programa de 8 semanas para ayudar a una persona
      mayor a cuidar su funcion cognitiva practica: orientarse mejor, reducir
      postergacion, completar metas semanales pequenas y fortalecer habitos de
      sueno, alimentacion, movimiento y apoyo social. No entrega diagnosticos ni
      indicaciones medicas. Refuerza adherencia a indicaciones del equipo de
      salud, apoyo del cuidador y escalamiento humano ante sintomas de riesgo.
    TEXT

    FOCUS_HINT = <<~TEXT.squish
      Usar mensajes muy breves, concretos y repetitivos. Enfocar en funcion
      cognitiva practica, metas semanales, primer paso de 2 minutos, sueno,
      alimentacion saludable, movimiento suave y apoyo del cuidador. No dar
      instrucciones medicas, no ajustar medicamentos, liquidos, sal ni
      tratamiento. Ante caida, confusion subita, debilidad de un lado, dolor de
      pecho, dificultad para hablar, presion muy alta o no poder orinar,
      recomendar contactar cuidador, medico o urgencia.
    TEXT

    COACH_NOTES = <<~TEXT.squish
      Programa creado para Francisco Valles, 72 anos, con hipertension,
      antecedentes de multiples ACV/derrames, deterioro cognitivo relevante,
      problemas de audicion, problemas prostaticos y sueno desordenado.
      Mantener supervision humana. Evitar audio como canal principal. Preferir
      texto corto, preguntas si/no y metas pequenas. Estos datos son contexto
      administrativo y no deben copiarse literalmente al participante.
    TEXT

    WEEKS = [
      {
        theme: "Orden externo para pensar con menos esfuerzo",
        goal: "Usar una pizarra o libreta cada manana con fecha, una tarea y un cuidado de salud.",
        evidence: "El cerebro trabaja mejor cuando no tiene que recordarlo todo. Las ayudas externas reducen carga mental.",
        actions: [
          "mirar calendario y decir dia, mes y ano",
          "escribir una sola tarea importante para hoy",
          "poner medicamentos y controles en un lugar visible, sin cambiar indicaciones",
          "dejar lentes, audifono o libreta siempre en el mismo lugar",
          "marcar en la pizarra si la tarea del dia quedo hecha",
          "ordenar por 5 minutos un espacio pequeno",
          "repasar con un cuidador que funciono esta semana"
        ]
      },
      {
        theme: "Sueno que protege claridad mental",
        goal: "Repetir una rutina corta antes de dormir al menos 5 noches.",
        evidence: "Dormir mejor ayuda a la atencion, el animo y el control de la presion. La AHA incluye el sueno como salud cardiovascular.",
        actions: [
          "elegir una hora tranquila para empezar a bajar el ritmo",
          "dejar el camino al bano despejado antes de acostarse",
          "apagar pantallas o bajar estimulos 30 minutos antes de dormir",
          "hacer una respiracion lenta de 5 ciclos antes de acostarse",
          "ir al bano antes de dormir, sin apuro y con luz segura",
          "anotar si desperto 0, 1 o 2+ veces durante la noche",
          "elegir el paso de sueno que mas ayudo esta semana"
        ]
      },
      {
        theme: "Comer para cuidar cerebro y presion",
        goal: "Agregar una eleccion mas protectora al dia, sin dietas extremas.",
        evidence: "El plan DASH del NHLBI promueve comidas con frutas, verduras, fibra y menos sodio para cuidar la presion.",
        actions: [
          "agregar una fruta o verdura a una comida",
          "preferir agua o bebida sin azucar segun indicacion habitual",
          "elegir una comida con menos sal o menos procesados",
          "comer sentado, lento y sin hacer otra tarea",
          "preguntar antes de repetir sal: 'esto ayuda a mi cabeza?'",
          "dejar lista una opcion saludable para manana",
          "nombrar la eleccion de comida que fue mas facil repetir"
        ]
      },
      {
        theme: "Menos postergacion, mas primer paso",
        goal: "Completar 3 tareas pequenas pendientes usando la regla de 2 minutos.",
        evidence: "La postergacion baja cuando el primer paso esta definido. Los planes si-entonces ayudan a empezar.",
        actions: [
          "elegir una tarea pendiente y hacer solo 2 minutos",
          "decir: si pienso 'despues', entonces hago el primer paso ahora",
          "dividir una tarea en abrir, mirar y decidir",
          "dejar preparado lo necesario para una llamada o tramite",
          "pedir ayuda para una tarea que esta trabada",
          "cerrar una tarea pequena antes de almorzar",
          "contar las tareas pequenas terminadas esta semana"
        ]
      },
      {
        theme: "Memoria practica y continuidad",
        goal: "Usar lista diaria de 3 puntos: hoy, salud, pendiente.",
        evidence: "Usar libreta, rutina y senales visibles no es hacer trampa; es una estrategia de compensacion cognitiva.",
        actions: [
          "escribir tres palabras: fecha, tarea, cuidado",
          "tachar la tarea terminada en vez de confiar en la memoria",
          "dejar una nota para el primer paso de manana",
          "repetir en voz alta la meta semanal",
          "revisar la lista despues de almuerzo",
          "poner una alarma o recordatorio con ayuda",
          "guardar la lista de la semana y mirar avances"
        ]
      },
      {
        theme: "Atencion, audicion y conversacion",
        goal: "Tener 4 conversaciones breves con menos ruido y mas contacto visual.",
        evidence: "Cuando oir cuesta, el cerebro gasta mas energia. Reducir ruido y mirar a la persona facilita entender.",
        actions: [
          "pedir que le hablen de frente y mas lento",
          "bajar ruido de tele o radio durante una conversacion",
          "repetir lo entendido con una frase corta",
          "hacer una llamada o conversacion breve acompanada",
          "anotar una pregunta para hacer a un familiar",
          "usar el apoyo auditivo disponible si corresponde",
          "elegir el ambiente donde escucho mejor esta semana"
        ]
      },
      {
        theme: "Metas semanales con sentido",
        goal: "Elegir una meta personal pequena y cumplir 4 pasos.",
        evidence: "Las metas funcionan mejor cuando son pequenas, visibles y conectadas con algo importante para la persona.",
        actions: [
          "elegir una meta de la semana en una frase",
          "definir cuando y donde hara el primer paso",
          "hacer un paso de 5 minutos hacia la meta",
          "preparar el siguiente paso antes de terminar",
          "pedir al cuidador que pregunte por la meta",
          "celebrar una accion hecha, aunque sea pequena",
          "decidir si la meta sigue o se ajusta"
        ]
      },
      {
        theme: "Mantener lo que funciona",
        goal: "Dejar una rutina de continuidad con 3 habitos ganadores.",
        evidence: "Los habitos duran mas cuando quedan pegados a una senal diaria: desayuno, almuerzo, tarde o acostarse.",
        actions: [
          "elegir el habito de manana que quiere mantener",
          "elegir el habito de noche que quiere mantener",
          "elegir el habito de comida o movimiento que quiere mantener",
          "hacer una tarjeta con sus 3 habitos",
          "practicar la rutina completa con apoyo",
          "definir quien revisara la rutina una vez por semana",
          "cerrar el programa leyendo sus 3 habitos ganadores"
        ]
      }
    ].freeze

    def call
      program = upsert_program
      upsert_day_contents(program)
      participant = assign_participant(program)
      schedule_first_day(participant) if participant && ENV["SCHEDULE_FIRST_DAY"] == "true"

      puts "Seeded '#{program.name}' (#{program.slug}) - #{program.day_contents.count} dias"
      puts "Assigned participant #{participant.name} to day #{participant.current_day}" if participant
    end

    private

    def upsert_program
      Program.find_or_initialize_by(slug: SLUG).tap do |program|
        program.assign_attributes(
          name: "Cerebro en Marcha",
          description: "Programa de 8 semanas para funcion cognitiva practica, metas semanales, menos postergacion y habitos saludables.",
          manifesto: MANIFESTO,
          total_days: 56,
          response_mode: "approve",
          active: true
        )
        program.save!
      end
    end

    def upsert_day_contents(program)
      WEEKS.each_with_index do |week, week_index|
        week[:actions].each_with_index do |action, day_index|
          day_number = (week_index * 7) + day_index + 1
          record = DayContent.find_or_initialize_by(program: program, day_number: day_number)
          record.assign_attributes(day_attrs(day_number, week_index + 1, day_index + 1, week, action))
          record.save!
        end
      end
    end

    def day_attrs(day_number, week_number, day_in_week, week, action)
      {
        active: true,
        phase: phase_for(day_number),
        title: "Semana #{week_number}, dia #{day_in_week}: #{week[:theme]}",
        template_name_whatsapp: format("despertar_dia_%02d", day_number),
        morning_template: "{name}, dia #{day_number}. #{week[:evidence]} Hoy el paso es simple: #{action}.",
        iareto_text: "Reto de hoy: #{action}. Hazlo pequeno y visible. Si aparece 'despues', haz solo 2 minutos.",
        checkin_questions: "1. Dormiste bien, regular o mal?\n2. Hiciste el reto de hoy? si/no\n3. Que tarea pequena terminaste o dejaste lista?",
        ai_system_prompt: system_prompt(day_number, week_number, week, action)
      }
    end

    def phase_for(day_number)
      return :see if day_number <= 14
      return :choose if day_number <= 35

      :anchor
    end

    def system_prompt(day_number, week_number, week, action)
      <<~TEXT.squish
        Dia #{day_number}, semana #{week_number}. Tema: #{week[:theme]}.
        Meta semanal: #{week[:goal]}. Evidencia para convencer sin asustar:
        #{week[:evidence]} Accion concreta de hoy: #{action}. Escribe en
        espanol chileno simple, con frases cortas y una sola instruccion. Debe
        sonar respetuoso, adulto y practico. No infantilizar. No dar
        diagnosticos ni indicaciones medicas; no cambiar medicamentos, dieta
        medica, sal, liquidos ni tratamiento prostatico. Reforzar que consulte
        al cuidador/equipo medico ante sintomas de riesgo. Priorizar texto
        breve por problemas de audicion.
      TEXT
    end

    def assign_participant(program)
      participant_id = ENV["PARTICIPANT_ID"].presence
      return unless participant_id

      participant = Participant.kept.find(participant_id)

      PaperTrail.request(whodunnit: "system:CerebroEnMarchaSeed", controller_info: { source: "system" }) do
        participant.enrollments.active.where.not(program: program).find_each(&:canceled!)
        participant.update!(
          program: program,
          status: :active,
          current_day: 1,
          response_mode: "auto",
          focus_hint: FOCUS_HINT,
          coach_notes: [ participant.coach_notes, COACH_NOTES ].compact_blank.join("\n\n"),
          pending_checkin_at: nil,
          started_at: Time.current,
          enrolled_at: participant.enrolled_at || Time.current
        )
        participant.start_enrollment!(program)
      end

      participant
    end

    def schedule_first_day(participant)
      wake_hour = Setting.fetch("wake_hour").to_i
      local_run_at = participant.local_time.tomorrow.change(hour: wake_hour, min: 0, sec: 0)
      MorningWakeForParticipantJob.set(wait_until: local_run_at).perform_later(participant.id)
      puts "Scheduled first day wake for #{local_run_at}"
    end
  end
end

Seeds::CerebroEnMarcha.new.call
