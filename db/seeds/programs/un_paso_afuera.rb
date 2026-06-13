# Seed idempotente del programa "Un paso afuera" (21 días, secuencial).
# Tema universal: atreverse a moverse hacia afuera —del cuerpo, hacia la gente,
# hacia el mundo— en micro-actos diarios. El contenido NUNCA nombra ni asume la
# situación específica de ninguna persona; cada participante se auto-aplica donde
# le duele. El contexto real de cada participante vive en coach_notes/focus_hint
# (admin-only), nunca aquí.
#
# Ejecutar:  asdf exec bundle exec rails runner db/seeds/programs/un_paso_afuera.rb
# En prod:   kamal app exec "bin/rails runner db/seeds/programs/un_paso_afuera.rb"
module Seeds
  module UnPasoAfuera
    module_function

    SLUG = "un-paso-afuera".freeze

    MANIFESTO = <<~TEXT.freeze
      Eres un acompañante de cambio basado en la metodología de Francisco Vallés (comtraining.cl).
      Acompañas a una persona durante 21 días a dar pequeños pasos hacia afuera: hacia el movimiento
      del cuerpo, hacia las personas y hacia el mundo. Tu apuesta es el coraje de lo pequeño: una
      micro-acción aplicada vale más que una gran intención.

      El programa tiene tres fases — VER (días 1–6), ELEGIR (días 7–15) y ANCLAR (días 16–21).

      Cómo hablas:
      - Como un par que camina al lado, no como un experto que diagnostica desde arriba.
      - Con calidez, respeto y claridad. Lenguaje cercano, sin emojis ni jerga.
      - No das órdenes ni psicoeducación: invitas a notar, elegir y probar.
      - Tratas a la persona como un adulto capaz de tomar sus propias decisiones.

      Qué NUNCA haces:
      - No nombras ni supones cuál es "el problema" de la persona (peso, trabajo, timidez, vida
        personal, etc.). Hablas siempre de lo universal —dar un paso hacia afuera— y dejas que ella
        lo aplique a su vida. Nunca le hagas sentir que sabes algo privado de ella.
      - No interpretas, no etiquetas, no suenas a manual ni a terapia. Si reconoce una técnica, igual
        mantienes el tono de par.
      - No das diagnósticos médicos ni psicológicos. Si la persona expresa angustia profunda o crisis,
        la orientas con respeto hacia un profesional de salud mental y le das contención básica.
      - No inventas datos.

      Formato de respuesta:
      - Brevedad. Máximo 4 frases por mensaje. Español claro y cálido.
      - Tu salida llega por WhatsApp: evita listas largas y markdown.
      - Cierras con una pregunta de reflexión o una micro-acción concreta.
    TEXT

    DAYS = [
      # ── VER (1–6): notar sin juzgar ──────────────────────────────────────
      {
        day_number: 1, phase: :see, title: "¿Dónde te quedas quieta?",
        morning_template: "Hola {name}. Durante 21 días vamos a dar pequeños pasos hacia afuera, juntos. Hoy no cambies nada: solo nota un momento del día en que elegiste lo cómodo en vez de moverte.",
        iareto_text: "Reto de hoy: cuando notes que prefieres quedarte donde estás, no hagas nada distinto. Solo regístralo mentalmente: «aquí elegí lo cómodo».",
        checkin_questions: "1. ¿En qué momento de hoy elegiste lo cómodo?\n2. ¿Qué sentiste justo antes de quedarte quieta?\n3. ¿Qué notaste al observarlo sin corregirlo?",
        ai_system_prompt: "Día 1 — VER. Solo ayudar a observar momentos de comodidad/quietud en la vida cotidiana. No aconsejar, no empujar todavía, no nombrar ningún problema concreto.",
        template_name_whatsapp: "despertar_dia_01"
      },
      {
        day_number: 2, phase: :see, title: "Tu cuerpo te habla",
        morning_template: "Buen día, {name}. Hoy observa tu energía: en qué momentos sube y en cuáles se apaga. No la juzgues, solo nótala como quien lee el clima.",
        iareto_text: "Reto de hoy: tres veces durante el día, pregúntate «¿cómo está mi energía ahora?» y ponle una palabra. Nada más.",
        checkin_questions: "1. ¿Cuándo sentiste más energía hoy?\n2. ¿Cuándo se apagó?\n3. ¿Qué estabas haciendo en cada caso?",
        ai_system_prompt: "Día 2 — VER. Reflejar la relación de la persona con su energía y su cuerpo, sin recomendar ejercicio ni hábitos. Observación pura.",
        template_name_whatsapp: "despertar_dia_02"
      },
      {
        day_number: 3, phase: :see, title: "El centímetro",
        morning_template: "{name}, hoy identifica una cosa pequeña que vienes posponiendo. No la hagas todavía. Solo nómbrala con honestidad.",
        iareto_text: "Reto de hoy: escribe en una línea esa cosa pequeña que sigues dejando para después. Tenerla nombrada ya es un paso.",
        checkin_questions: "1. ¿Qué cosa pequeña llevas posponiendo?\n2. ¿Qué pasa por tu cabeza cuando piensas en hacerla?\n3. ¿Hace cuánto la vienes dejando?",
        ai_system_prompt: "Día 3 — VER. Ayudar a nombrar una postergación pequeña, sin presionar a actuar. Acoger la evitación sin juicio.",
        template_name_whatsapp: "despertar_dia_03"
      },
      {
        day_number: 4, phase: :see, title: "Lo que te encoge",
        morning_template: "Cuarto día, {name}. Hoy nota un momento en que te hiciste pequeña o preferiste no aparecer. No hace falta cambiarlo: solo verlo.",
        iareto_text: "Reto de hoy: detecta una sola situación donde te quedaste atrás o te callaste algo. Obsérvala como dato, no como falla.",
        checkin_questions: "1. ¿En qué momento te hiciste pequeña hoy?\n2. ¿Qué temías que pasara si aparecías más?\n3. ¿Qué te dice eso, sin juzgarte?",
        ai_system_prompt: "Día 4 — VER. Reflejar momentos de retraimiento/invisibilidad en términos universales. Nunca etiquetar a la persona como tímida ni nombrar un rasgo.",
        template_name_whatsapp: "despertar_dia_04"
      },
      {
        day_number: 5, phase: :see, title: "Tu zona segura",
        morning_template: "{name}, hoy mira tu zona cómoda: eso que te da seguridad y a lo que vuelves siempre. Todo refugio tiene un precio. Hoy solo míralo.",
        iareto_text: "Reto de hoy: identifica un hábito o lugar al que vuelves por comodidad, y pregúntate qué te cuesta quedarte ahí.",
        checkin_questions: "1. ¿Cuál es tu zona segura más fuerte?\n2. ¿Qué te da?\n3. ¿Qué te quita quedarte siempre dentro?",
        ai_system_prompt: "Día 5 — VER. Explorar comodidad vs. costo, en abstracto. No prescribir salir aún; solo iluminar el intercambio.",
        template_name_whatsapp: "despertar_dia_05"
      },
      {
        day_number: 6, phase: :see, title: "La foto de hoy",
        morning_template: "Sexto día, {name}. Ya tienes varias pistas. Hoy arma una foto simple de cómo te mueves por la vida hoy: qué te mueve, qué te frena, qué evitas.",
        iareto_text: "Reto de hoy: resume en una sola frase honesta cómo te mueves hoy por tu vida. Sin adornos.",
        checkin_questions: "1. ¿Cómo resumirías hoy tu forma de moverte por la vida?\n2. ¿Qué parte de esa foto te incomoda?\n3. ¿Qué parte sí quieres conservar?",
        ai_system_prompt: "Día 6 — Cierre de VER. Sintetizar lo observado y preparar la transición a ELEGIR. Devolver una foto, no un diagnóstico.",
        template_name_whatsapp: "despertar_dia_06"
      },
      # ── ELEGIR (7–15): un micro-acto valiente al día ─────────────────────
      {
        day_number: 7, phase: :choose, title: "Mover el cuerpo",
        morning_template: "{name}, hoy empieza ELEGIR. Tu micro-acto: mover el cuerpo 10 minutos, como sea —caminar, estirar, bailar—. No para rendir, solo para moverte.",
        iareto_text: "Reto de hoy: 10 minutos de movimiento, en el momento del día que tú elijas. Cuenta cualquier forma de moverte.",
        checkin_questions: "1. ¿Cómo moviste tu cuerpo hoy?\n2. ¿Cómo te sentiste antes y después?\n3. ¿Qué te costó empezar?",
        ai_system_prompt: "Día 7 — ELEGIR. Reforzar el primer micro-acto físico como puerta de entrada a la agencia. Celebrar el hecho de moverse, no la intensidad.",
        template_name_whatsapp: "despertar_dia_07"
      },
      {
        day_number: 8, phase: :choose, title: "Tender un puente",
        morning_template: "{name}, hoy el paso es hacia alguien. Escríbele a una persona con la que perdiste contacto. Un mensaje corto basta.",
        iareto_text: "Reto de hoy: manda un mensaje a alguien con quien hace tiempo no hablas. No tiene que ser profundo; basta con reaparecer.",
        checkin_questions: "1. ¿A quién le escribiste?\n2. ¿Qué sentiste al mandar el mensaje?\n3. ¿Qué pasó después?",
        ai_system_prompt: "Día 8 — ELEGIR. Acompañar un micro-acto de conexión. Reconocer el coraje de reaparecer, sin presionar a que la respuesta sea perfecta.",
        template_name_whatsapp: "despertar_dia_08"
      },
      {
        day_number: 9, phase: :choose, title: "Hecho, no perfecto",
        morning_template: "{name}, hoy retoma esa cosa pequeña que pospones. Hazla ahora, aunque salga imperfecta. Hecho vale más que perfecto.",
        iareto_text: "Reto de hoy: haz esa tarea aplazada de forma deliberadamente imperfecta. El objetivo es terminarla, no que quede impecable.",
        checkin_questions: "1. ¿Qué hiciste que venías posponiendo?\n2. ¿Qué tan imperfecto te permitiste ser?\n3. ¿Qué se sintió al cerrarlo?",
        ai_system_prompt: "Día 9 — ELEGIR. Reforzar acción imperfecta sobre perfeccionismo/parálisis. Validar el cierre, no la calidad.",
        template_name_whatsapp: "despertar_dia_09"
      },
      {
        day_number: 10, phase: :choose, title: "Aparecer",
        morning_template: "{name}, hoy ocupa un poco más de espacio. Di en voz alta algo que normalmente te callarías, o muestra algo tuyo a alguien.",
        iareto_text: "Reto de hoy: una vez, di lo que piensas o muestra algo tuyo en lugar de guardarlo. Una frase basta.",
        checkin_questions: "1. ¿Qué dijiste o mostraste que normalmente callarías?\n2. ¿Qué temías antes de hacerlo?\n3. ¿Qué pasó en realidad?",
        ai_system_prompt: "Día 10 — ELEGIR. Exposición segura: aparecer un poco más. Reconocer el riesgo percibido vs. lo que realmente ocurrió.",
        template_name_whatsapp: "despertar_dia_10"
      },
      {
        day_number: 11, phase: :choose, title: "Un paso hacia lo que quieres",
        morning_template: "{name}, hoy da un paso hacia algo que quieres pero que no te has atrevido a buscar. Un paso pequeño y concreto, no el salto entero.",
        iareto_text: "Reto de hoy: identifica algo que deseas y da el primer paso mínimo hacia ello —una búsqueda, un mensaje, una pregunta—.",
        checkin_questions: "1. ¿Hacia qué quisiste dar un paso?\n2. ¿Cuál fue el paso mínimo que diste?\n3. ¿Qué se interpuso o casi se interpone?",
        ai_system_prompt: "Día 11 — ELEGIR. Acompañar un paso hacia un deseo propio (sin asumir cuál: trabajo, vínculo, proyecto…). Enfocar en el paso, no en el resultado.",
        template_name_whatsapp: "despertar_dia_11"
      },
      {
        day_number: 12, phase: :choose, title: "Romper el molde",
        morning_template: "{name}, hoy rompe una rutina cómoda: cambia un camino, un horario, una forma de hacer algo de siempre. Pequeño, pero distinto.",
        iareto_text: "Reto de hoy: haz una cosa cotidiana de una manera nueva. El punto es sentir que lo de siempre no es lo único posible.",
        checkin_questions: "1. ¿Qué rutina cambiaste hoy?\n2. ¿Cómo se sintió salir de lo automático?\n3. ¿Qué descubriste al hacerlo distinto?",
        ai_system_prompt: "Día 12 — ELEGIR. Flexibilidad: mostrar que lo habitual es elegible. Reforzar la sensación de agencia sobre lo cotidiano.",
        template_name_whatsapp: "despertar_dia_12"
      },
      {
        day_number: 13, phase: :choose, title: "Pedir",
        morning_template: "{name}, hoy pide algo pequeño a alguien: ayuda, una opinión, un favor. Pedir también es atreverse a aparecer.",
        iareto_text: "Reto de hoy: haz una petición pequeña a otra persona, en lugar de arreglártelas sola por defecto.",
        checkin_questions: "1. ¿Qué pediste y a quién?\n2. ¿Qué te costó de pedir?\n3. ¿Cómo respondió la otra persona?",
        ai_system_prompt: "Día 13 — ELEGIR. Pedir como exposición y vínculo. Validar la dificultad de pedir sin interpretarla como carencia.",
        template_name_whatsapp: "despertar_dia_13"
      },
      {
        day_number: 14, phase: :choose, title: "Un minuto más",
        morning_template: "{name}, hoy cuando aparezca la incomodidad de moverte, quédate ahí un minuto más antes de retroceder. El coraje se entrena en esos segundos.",
        iareto_text: "Reto de hoy: en un momento incómodo, resiste un minuto más de lo habitual antes de volver a lo cómodo.",
        checkin_questions: "1. ¿En qué momento sostuviste la incomodidad?\n2. ¿Qué querías hacer para escapar de ella?\n3. ¿Qué cambió al quedarte un poco más?",
        ai_system_prompt: "Día 14 — ELEGIR. Tolerancia a la incomodidad. Reforzar quedarse un poco más sin dramatizar ni exigir aguante heroico.",
        template_name_whatsapp: "despertar_dia_14"
      },
      {
        day_number: 15, phase: :choose, title: "El paso, no el resultado",
        morning_template: "{name}, cierras ELEGIR. Hoy elige un paso pequeño y date el mérito solo por darlo, sin importar cómo salga. El paso es tuyo; el resultado no siempre.",
        iareto_text: "Reto de hoy: da un micro-paso a tu elección y, al final, reconócete por haberlo dado —pase lo que pase con el resultado—.",
        checkin_questions: "1. ¿Qué paso elegiste hoy?\n2. ¿Pudiste separarlo del resultado?\n3. ¿Qué se siente darse el mérito por el paso mismo?",
        ai_system_prompt: "Día 15 — Cierre de ELEGIR. Desacoplar acción de resultado; fortalecer autoeficacia. Preparar la transición a ANCLAR.",
        template_name_whatsapp: "despertar_dia_15"
      },
      # ── ANCLAR (16–21): volverlo identidad ───────────────────────────────
      {
        day_number: 16, phase: :anchor, title: "Ya lo hiciste",
        morning_template: "{name}, hoy empieza ANCLAR. Mira atrás: hubo micro-actos que costaron y que igual lograste. Eso ya eres tú moviéndote.",
        iareto_text: "Reto de hoy: recuerda un paso de estas dos semanas que costó y se hizo igual. Léelo como evidencia, no como excepción.",
        checkin_questions: "1. ¿Qué paso recuerdas que costó y lograste?\n2. ¿Qué te dice eso de ti?\n3. ¿Qué cambia si lo crees de verdad?",
        ai_system_prompt: "Día 16 — ANCLAR. Recoger evidencia de logros propios. Ayudar a que la persona se atribuya el cambio, sin sobreinterpretar.",
        template_name_whatsapp: "despertar_dia_16"
      },
      {
        day_number: 17, phase: :anchor, title: "El patrón nuevo",
        morning_template: "{name}, de todos los pasos de estos días, ¿cuál quieres convertir en costumbre? Hoy elige uno para sostener.",
        iareto_text: "Reto de hoy: elige un micro-acto que quieras volver hábito y hazlo otra vez hoy, a propósito.",
        checkin_questions: "1. ¿Qué paso quieres volver hábito?\n2. ¿Qué lo hace valioso para ti?\n3. ¿Cuándo lo repetirías cada día?",
        ai_system_prompt: "Día 17 — ANCLAR. Convertir un micro-acto en hábito elegido. Aterrizar el cuándo/cómo concreto.",
        template_name_whatsapp: "despertar_dia_17"
      },
      {
        day_number: 18, phase: :anchor, title: "Cuando vuelva el miedo",
        morning_template: "{name}, habrá días en que querrás quedarte quieta. Hoy preparemos ese día: ¿cuál será tu paso mínimo cuando no tengas ganas de ninguno?",
        iareto_text: "Reto de hoy: define tu «paso de emergencia»: la acción más pequeña posible que harás los días sin impulso.",
        checkin_questions: "1. ¿Cuál será tu paso mínimo en los días difíciles?\n2. ¿Qué señales te avisan que viene un día así?\n3. ¿Cómo te hablarás cuando llegue?",
        ai_system_prompt: "Día 18 — ANCLAR. Plan para recaídas/días bajos. Definir un piso mínimo y autocompasión, sin exigir constancia perfecta.",
        template_name_whatsapp: "despertar_dia_18"
      },
      {
        day_number: 19, phase: :anchor, title: "Tu red",
        morning_template: "{name}, no se avanza sola del todo. Hoy piensa en quién te acompaña cuando te mueves, y acércate un poco más a esa persona.",
        iareto_text: "Reto de hoy: cuéntale a alguien de confianza un paso que diste estos días. Hacer pública tu intención la sostiene.",
        checkin_questions: "1. ¿Con quién compartiste un paso tuyo?\n2. ¿Cómo se sintió decirlo en voz alta?\n3. ¿Quién más podría acompañarte de aquí en adelante?",
        ai_system_prompt: "Día 19 — ANCLAR. Apoyo social como sostén del cambio. Reforzar el valor de hacer pública la intención.",
        template_name_whatsapp: "despertar_dia_19"
      },
      {
        day_number: 20, phase: :anchor, title: "El siguiente centímetro",
        morning_template: "{name}, el programa casi termina, pero el movimiento no. Hoy mira hacia adelante: ¿cuál es el próximo paso hacia afuera, ya sin que yo te lo pida?",
        iareto_text: "Reto de hoy: nombra un paso que quieras dar la próxima semana, por tu cuenta. Escríbelo donde lo vuelvas a ver.",
        checkin_questions: "1. ¿Cuál es tu próximo paso, ya sin guía?\n2. ¿Cuándo lo darás?\n3. ¿Qué te dice que ya puedes elegirlo sola?",
        ai_system_prompt: "Día 20 — ANCLAR. Proyectar autonomía más allá del programa. Transferir la iniciativa a la persona.",
        template_name_whatsapp: "despertar_dia_20"
      },
      {
        day_number: 21, phase: :anchor, title: "Soy alguien que da el paso",
        morning_template: "{name}, último día. Mira el camino: empezaste observando dónde te quedabas quieta y hoy eres alguien que da el paso. Eso no es de estos 21 días: es tuyo.",
        iareto_text: "Reto de hoy: completa esta frase para ti y guárdala: «Soy alguien que…». Que describa a la persona en movimiento que has practicado ser.",
        checkin_questions: "1. ¿Cómo completas «soy alguien que…» hoy?\n2. ¿Qué fue lo más importante que aprendiste de ti?\n3. ¿Qué quieres llevarte de aquí en adelante?",
        ai_system_prompt: "Día 21 — Cierre de ANCLAR. Consolidar identidad de persona que actúa. Tono de celebración serena; preparar el manifiesto de cierre.",
        template_name_whatsapp: "despertar_dia_21"
      }
    ].freeze

    def call
      program = Program.find_or_initialize_by(slug: SLUG)
      program.assign_attributes(
        name: "Un paso afuera",
        description: "Programa de 21 días para atreverse a moverse hacia afuera —del cuerpo, hacia la gente, hacia el mundo— en micro-actos diarios. Fases VER (1–6), ELEGIR (7–15) y ANCLAR (16–21).",
        manifesto: MANIFESTO,
        total_days: 21,
        active: true
      )
      program.save!

      DAYS.each do |attrs|
        record = DayContent.find_or_initialize_by(program: program, day_number: attrs[:day_number])
        record.assign_attributes(attrs.merge(active: true, program: program))
        record.save!
      end

      puts "Seeded '#{program.name}' (#{program.slug}) — #{program.day_contents.count} días"
    end
  end
end

Seeds::UnPasoAfuera.call if defined?(Program)
