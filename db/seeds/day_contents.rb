BASE_MANIFESTO = <<~TEXT.freeze
  Eres parte de Impulso by Comtraining: un programa de 14 días que acompaña a la persona a
  convertir intención en conducta a través de tres fases — VER (días 1–5), ELEGIR (días 6–10)
  y ANCLAR (días 11–14). Principios:

  1. No enseñar desde arriba, sino activar conciencia y práctica.
  2. La persona descubre y experimenta; tú reflejas, ordenas y enfocas.
  3. Brevedad. Máximo 4 frases. Sin emojis. Español claro y ejecutivo.
  4. Tono cálido, lúcido y concreto. Sin coaching grandilocuente.
  5. Honra lo pequeño. Una micro-acción aplicada vale más que una gran intención.
  6. Refleja lo que la persona ya dijo antes de añadir algo nuevo.

  Tu salida llega por WhatsApp, así que evita listas largas y formato markdown.
TEXT

PROGRAM_DEFINITIONS = [
  {
    slug: "impulso-liderazgo-en-accion",
    name: "Impulso Liderazgo en Acción",
    description: "Programa de 14 días para reforzar hábitos concretos de liderazgo, seguimiento y conversaciones clave.",
    active: true,
    audience: "jefaturas, mandos medios y líderes de proyecto",
    pattern_prompt: "¿Qué hábito de liderazgo necesitas fortalecer durante estas dos semanas?",
    theme: "liderazgo"
  },
  {
    slug: "impulso-cambio-en-accion",
    name: "Impulso Cambio en Acción",
    description: "Programa de 14 días para sostener conductas que faciliten adopción, coordinación y ejecución del cambio.",
    active: true,
    audience: "equipos y líderes en procesos de transformación",
    pattern_prompt: "¿Qué comportamiento ayudaría más a que el cambio avance de verdad en tu día a día?",
    theme: "cambio"
  },
  {
    slug: "impulso-productividad-sostenible",
    name: "Impulso Productividad Sostenible",
    description: "Programa de 14 días para trabajar foco, energía y priorización sin caer en productividad reactiva.",
    active: true,
    audience: "profesionales y equipos con alta carga y dispersión",
    pattern_prompt: "¿Qué patrón de trabajo te está quitando más foco o energía hoy?",
    theme: "productividad"
  }
].freeze

PHASE_RANGES = {
  see: 1..5,
  choose: 6..10,
  anchor: 11..14
}.freeze

def program_manifesto(theme:, audience:, pattern_prompt:)
  <<~TEXT
    #{BASE_MANIFESTO}

    Contexto específico:
    - Tema central: #{theme}.
    - Audiencia principal: #{audience}.
    - Pregunta de activación inicial: #{pattern_prompt}
    - Busca ejemplos observables en trabajo real: reuniones, prioridades, conversaciones, coordinación, foco y seguimiento.
  TEXT
end

def seed_program!(definition)
  program = Program.find_or_initialize_by(slug: definition[:slug])
  program.assign_attributes(
    name: definition[:name],
    description: definition[:description],
    manifesto: program_manifesto(
      theme: definition[:theme],
      audience: definition[:audience],
      pattern_prompt: definition[:pattern_prompt]
    ),
    total_days: 14,
    active: definition[:active]
  )
  program.save!

  build_days_for(definition).each do |attrs|
    record = DayContent.find_or_initialize_by(program: program, day_number: attrs[:day_number])
    record.assign_attributes(attrs.merge(active: true, program: program))
    record.save!
  end

  puts "Seeded #{program.day_contents.count} day contents for '#{program.name}'"
end

def build_days_for(definition)
  case definition[:slug]
  when "impulso-liderazgo-en-accion"
    liderazgo_days
  when "impulso-cambio-en-accion"
    cambio_days
  when "impulso-productividad-sostenible"
    productividad_days
  else
    raise "Unknown program slug: #{definition[:slug]}"
  end
end

def liderazgo_days
  [
    {
      day_number: 1, phase: :see,
      title: "Inventario de Liderazgo",
      morning_template: "Hola {name}. Durante 14 días vas a observar y reforzar tu forma de liderar. Hoy no cambies nada: solo nota en qué momentos diriges en automático.",
      iareto_text: "IAReto Día 1: Identifica tres momentos de liderazgo hoy: una conversación, una decisión y un seguimiento. Solo obsérvalos.",
      checkin_questions: "1. ¿En qué momento lideraste más en automático hoy?\n2. ¿Dónde estuviste más presente?\n3. ¿Qué te llamó la atención de esa diferencia?",
      ai_system_prompt: "Día 1 — Inventario de Liderazgo. Fase VER. No aconsejes. Ayuda a observar momentos reales de liderazgo en trabajo cotidiano.",
      template_name_whatsapp: "despertar_dia_01"
    },
    {
      day_number: 2, phase: :see,
      title: "Conversaciones que Postergas",
      morning_template: "Buen día, {name}. Hoy observa qué conversación importante tiendes a postergar cuando el día se acelera. No la fuerces todavía. Solo nómbrala.",
      iareto_text: "IAReto Día 2: Cada vez que pienses 'después lo veo', pregúntate si ahí hay una conversación que estás aplazando.",
      checkin_questions: "1. ¿Qué conversación importante postergaste o casi postergaste?\n2. ¿Qué te hizo evitarla?\n3. ¿Qué costo tiene seguir difiriéndola?",
      ai_system_prompt: "Día 2 — Conversaciones Postergadas. Refleja evitación, carga emocional y costo del aplazamiento sin juicio.",
      template_name_whatsapp: "despertar_dia_02"
    },
    {
      day_number: 3, phase: :see,
      title: "Mapa de Reacciones",
      morning_template: "{name}, hoy observa cómo reaccionas cuando algo se desvía: un atraso, un error, una tensión. El liderazgo suele mostrarse más ahí que en los planes.",
      iareto_text: "IAReto Día 3: Detecta tu primera reacción ante una fricción real. No la corrijas todavía; solo regístrala mentalmente.",
      checkin_questions: "1. ¿Qué situación gatilló tu reacción más automática hoy?\n2. ¿Cómo reaccionaste?\n3. ¿Qué efecto tuvo esa reacción en otros?",
      ai_system_prompt: "Día 3 — Mapa de Reacciones. Ayuda a ver disparador, respuesta y efecto interpersonal.",
      template_name_whatsapp: "despertar_dia_03"
    },
    {
      day_number: 4, phase: :see,
      title: "Señales para el Equipo",
      morning_template: "Cuarto día, {name}. Hoy mira tu liderazgo desde afuera: ¿qué señales reciben los demás de ti cuando estás bajo presión?",
      iareto_text: "IAReto Día 4: Elige un momento de hoy e imagina cómo lo habría descrito tu equipo en una frase.",
      checkin_questions: "1. ¿Qué señal crees que recibió tu equipo de ti hoy?\n2. ¿Era la señal que querías dar?\n3. ¿Qué te dice eso de tu forma actual de liderar?",
      ai_system_prompt: "Día 4 — Señales para el Equipo. Favorece perspectiva externa, sin dramatizar.",
      template_name_whatsapp: "despertar_dia_04"
    },
    {
      day_number: 5, phase: :see,
      title: "Foto del Liderazgo Actual",
      morning_template: "Quinto día, {name}. Ya tienes varias pistas. Hoy arma una foto simple de tu liderazgo actual: qué haces bien, qué repites y qué te está costando.",
      iareto_text: "IAReto Día 5: Resume tu liderazgo actual en una sola frase honesta. Sin adornos.",
      checkin_questions: "1. ¿Cómo resumirías hoy tu liderazgo en una frase?\n2. ¿Qué parte de esa foto te incomoda?\n3. ¿Qué parte sí vale la pena conservar?",
      ai_system_prompt: "Día 5 — Cierre de fase VER. Sintetiza y prepara la transición a ELEGIR.",
      template_name_whatsapp: "despertar_dia_05"
    },
    {
      day_number: 6, phase: :choose,
      title: "La Micro-elección",
      morning_template: "{name}, hoy comienza ELEGIR. No necesitas reinventar tu liderazgo: solo elegir una micro-acción mejor en un momento importante del día.",
      iareto_text: "IAReto Día 6: Antes de una conversación o seguimiento clave, define en una línea qué quieres provocar en el otro.",
      checkin_questions: "1. ¿Qué micro-elección hiciste hoy antes de liderar?\n2. ¿Qué cambió al hacerla?\n3. ¿Qué resistencia apareció?",
      ai_system_prompt: "Día 6 — Micro-elección. Refuerza intención previa y pequeñez aplicada.",
      template_name_whatsapp: "despertar_dia_06"
    },
    {
      day_number: 7, phase: :choose,
      title: "Pausa Antes de Reaccionar",
      morning_template: "Hoy, {name}, prueba una pausa breve antes de responder bajo presión. Liderar mejor a veces empieza por no contestar desde el primer impulso.",
      iareto_text: "IAReto Día 7: Haz una pausa de tres segundos antes de responder en al menos dos momentos tensos.",
      checkin_questions: "1. ¿En qué momento lograste pausar?\n2. ¿Qué evitó esa pausa?\n3. ¿Qué pasó distinto después?",
      ai_system_prompt: "Día 7 — Pausa antes de reaccionar. Refleja regulación y efecto en la interacción.",
      template_name_whatsapp: "despertar_dia_07"
    },
    {
      day_number: 8, phase: :choose,
      title: "Claridad en Seguimiento",
      morning_template: "{name}, hoy el reto no es hacer más seguimiento, sino hacerlo más claro. Una indicación ambigua genera retrabajo; una clara libera energía.",
      iareto_text: "IAReto Día 8: En un seguimiento real, define con precisión una expectativa, un plazo o un próximo paso.",
      checkin_questions: "1. ¿Dónde pusiste más claridad hoy?\n2. ¿Cómo respondió la otra persona?\n3. ¿Qué te mostró eso sobre tu manera de coordinar?",
      ai_system_prompt: "Día 8 — Claridad en Seguimiento. Favorece precisión, no sobrecontrol.",
      template_name_whatsapp: "despertar_dia_08"
    },
    {
      day_number: 9, phase: :choose,
      title: "Conversación Difícil, Paso Pequeño",
      morning_template: "Hoy, {name}, no necesitas resolver toda la conversación difícil. Solo abrirla mejor o moverla un paso.",
      iareto_text: "IAReto Día 9: Da un paso concreto hacia la conversación pendiente: agenda, abre contexto o formula la primera pregunta.",
      checkin_questions: "1. ¿Qué paso diste hacia la conversación difícil?\n2. ¿Qué facilitó moverla?\n3. ¿Qué te gustaría sostener mañana?",
      ai_system_prompt: "Día 9 — Paso pequeño en conversación difícil. Honra avance parcial y reduce épica innecesaria.",
      template_name_whatsapp: "despertar_dia_09"
    },
    {
      day_number: 10, phase: :choose,
      title: "Elegir el Estilo",
      morning_template: "{name}, último día de ELEGIR. Hoy repite a propósito una conducta distinta: más claridad, mejor pausa o una conversación menos evitada.",
      iareto_text: "IAReto Día 10: Repite una conducta elegida esta semana y observa cómo cambia tu sensación al hacerla de forma deliberada.",
      checkin_questions: "1. ¿Qué conducta elegiste repetir hoy?\n2. ¿Qué diferencia hubo respecto a días anteriores?\n3. ¿Qué quieres anclar en la fase final?",
      ai_system_prompt: "Día 10 — Cierre fase ELEGIR. Prepara paso a ANCLAR sin inflar el avance.",
      template_name_whatsapp: "despertar_dia_10"
    },
    {
      day_number: 11, phase: :anchor,
      title: "Ancla de Liderazgo",
      morning_template: "Entramos a ANCLAR, {name}. Elige una señal simple que te recuerde cómo quieres liderar: una reunión, una pregunta o un gesto antes de responder.",
      iareto_text: "IAReto Día 11: Define tu ancla de liderazgo y úsala hoy en un momento real.",
      checkin_questions: "1. ¿Cuál fue tu ancla de liderazgo?\n2. ¿Cuándo la usaste?\n3. ¿Qué efecto tuvo?",
      ai_system_prompt: "Día 11 — Ancla de Liderazgo. Busca concreción y repetibilidad.",
      template_name_whatsapp: "despertar_dia_11"
    },
    {
      day_number: 12, phase: :anchor,
      title: "Ritmo y Repetición",
      morning_template: "{name}, una conducta se sostiene mejor cuando tiene ritmo. Hoy decide en qué momento fijo del día activarás tu nueva forma de liderar.",
      iareto_text: "IAReto Día 12: Asocia tu ancla a un momento recurrente: antes del comité, al abrir Slack o al comenzar tu primera reunión.",
      checkin_questions: "1. ¿A qué momento del día amarraste tu ancla?\n2. ¿Funcionó?\n3. ¿Qué ajustarías para hacerla más sostenible?",
      ai_system_prompt: "Día 12 — Ritmo y repetición. Reforzar ajuste fino, no perfección.",
      template_name_whatsapp: "despertar_dia_12"
    },
    {
      day_number: 13, phase: :anchor,
      title: "Carta al Líder Reactivo",
      morning_template: "Penúltimo día, {name}. Hoy mira a tu versión reactiva de hace dos semanas. No para juzgarla, sino para cerrar una etapa con más conciencia.",
      iareto_text: "IAReto Día 13: Escribe una breve carta mental a tu yo líder reactivo: qué te protegía, qué ya no necesitas y qué eliges ahora.",
      checkin_questions: "1. ¿Qué le agradeciste a esa versión tuya?\n2. ¿Qué decidiste dejar atrás?\n3. ¿Cómo nombrarías tu nueva forma de liderar?",
      ai_system_prompt: "Día 13 — Carta al Líder Reactivo. Tono sereno, de cierre y apropiación.",
      template_name_whatsapp: "despertar_dia_13"
    },
    {
      day_number: 14, phase: :anchor,
      title: "Manifiesto de Liderazgo",
      morning_template: "Último día, {name}. Hoy no hay un reto nuevo. Hoy observas el tipo de liderazgo que comenzaste a construir y te preparas para recibir tu manifiesto.",
      iareto_text: "IAReto Día 14: Ningún reto nuevo. Camina el día atento a la conducta que quieres sostener más allá de estas dos semanas.",
      checkin_questions: "1. ¿Qué conducta de liderazgo quieres conservar?\n2. ¿Dónde necesitarás cuidarla más?\n3. ¿Cuál será tu próximo recordatorio práctico?",
      ai_system_prompt: "Día 14 — Manifiesto de Liderazgo. Cierre sobrio, claro y aplicable.",
      template_name_whatsapp: "despertar_dia_14"
    }
  ]
end

def cambio_days
  [
    {
      day_number: 1, phase: :see,
      title: "Inventario del Cambio Real",
      morning_template: "Hola {name}. Durante 14 días vas a observar cómo vives el cambio en la práctica. Hoy no intentes convencer a nadie. Solo nota qué conductas facilitan o frenan el avance.",
      iareto_text: "IAReto Día 1: Observa tres momentos del día donde el cambio avanzó o se frenó. No intervengas todavía.",
      checkin_questions: "1. ¿Dónde viste avanzar el cambio hoy?\n2. ¿Dónde se frenó?\n3. ¿Qué conducta estuvo detrás de cada caso?",
      ai_system_prompt: "Día 1 — Inventario del Cambio. Fase VER. Ayuda a observar conductas, no discursos.",
      template_name_whatsapp: "despertar_dia_01"
    },
    {
      day_number: 2, phase: :see,
      title: "Resistencia Concreta",
      morning_template: "Buen día, {name}. Hoy mira la resistencia sin dramatizarla. ¿Dónde aparece como demora, silencio, ambigüedad o cansancio?",
      iareto_text: "IAReto Día 2: Detecta una forma concreta de resistencia hoy. Nómbrala en términos observables.",
      checkin_questions: "1. ¿Qué forma de resistencia detectaste hoy?\n2. ¿Cómo se expresó?\n3. ¿Qué la pudo estar alimentando?",
      ai_system_prompt: "Día 2 — Resistencia Concreta. Diferencia interpretación de observación.",
      template_name_whatsapp: "despertar_dia_02"
    },
    {
      day_number: 3, phase: :see,
      title: "Puntos de Fricción",
      morning_template: "{name}, hoy observa dónde se traban las cosas: coordinación, prioridades, herramientas, decisiones o claridad. El cambio se cae más en la fricción diaria que en la estrategia.",
      iareto_text: "IAReto Día 3: Identifica un punto de fricción repetido y anota mentalmente qué lo hace costoso.",
      checkin_questions: "1. ¿Qué fricción repetida detectaste?\n2. ¿A quién afecta más?\n3. ¿Qué hace que siga repitiéndose?",
      ai_system_prompt: "Día 3 — Puntos de Fricción. Ayuda a aterrizar el costo operativo del cambio.",
      template_name_whatsapp: "despertar_dia_03"
    },
    {
      day_number: 4, phase: :see,
      title: "Señales de Adopción",
      morning_template: "Cuarto día, {name}. No todo es resistencia. Hoy mira señales de adopción real, aunque sean pequeñas.",
      iareto_text: "IAReto Día 4: Detecta una conducta nueva que sí esté apareciendo en el equipo o en ti. Solo una.",
      checkin_questions: "1. ¿Qué señal de adopción viste hoy?\n2. ¿Qué ayudó a que apareciera?\n3. ¿Cómo podrías reconocerla más a menudo?",
      ai_system_prompt: "Día 4 — Señales de Adopción. Refuerza progreso observable y no slogans.",
      template_name_whatsapp: "despertar_dia_04"
    },
    {
      day_number: 5, phase: :see,
      title: "Foto del Cambio Hoy",
      morning_template: "Quinto día, {name}. Ya tienes señales de avance, resistencia y fricción. Hoy arma una foto honesta de cómo se está viviendo el cambio realmente.",
      iareto_text: "IAReto Día 5: Resume el cambio actual en una frase que empiece con 'hoy, en la práctica...'.",
      checkin_questions: "1. ¿Cómo resumirías el cambio hoy en una frase?\n2. ¿Qué parte de esa foto es la más difícil?\n3. ¿Qué punto sí parece movible?",
      ai_system_prompt: "Día 5 — Cierre fase VER para cambio. Sintetiza la realidad operativa.",
      template_name_whatsapp: "despertar_dia_05"
    },
    {
      day_number: 6, phase: :choose,
      title: "La Palanca Pequeña",
      morning_template: "{name}, comienza ELEGIR. Hoy no vas a mover todo el sistema; solo buscar una palanca pequeña que facilite el cambio.",
      iareto_text: "IAReto Día 6: Elige una acción de bajo esfuerzo y alto impacto para destrabar un punto de fricción real.",
      checkin_questions: "1. ¿Qué palanca pequeña elegiste hoy?\n2. ¿Por qué esa?\n3. ¿Qué efecto tuvo o podría tener?",
      ai_system_prompt: "Día 6 — Palanca pequeña. Favorece pragmatismo y criterio de impacto.",
      template_name_whatsapp: "despertar_dia_06"
    },
    {
      day_number: 7, phase: :choose,
      title: "Claridad para Avanzar",
      morning_template: "Hoy, {name}, prueba esto: si algo del cambio no avanza, aumenta claridad antes de aumentar presión.",
      iareto_text: "IAReto Día 7: Aclara una expectativa, un próximo paso o un criterio de éxito en una conversación real.",
      checkin_questions: "1. ¿Qué aclaraste hoy?\n2. ¿Qué cambió al hacerlo?\n3. ¿Qué te mostró eso sobre el problema original?",
      ai_system_prompt: "Día 7 — Claridad antes que presión. Refleja calidad de coordinación.",
      template_name_whatsapp: "despertar_dia_07"
    },
    {
      day_number: 8, phase: :choose,
      title: "Escuchar la Fricción",
      morning_template: "{name}, hoy prueba escuchar una objeción o resistencia con más curiosidad y menos defensa. A veces ahí aparece información útil para el cambio.",
      iareto_text: "IAReto Día 8: En una objeción real, formula una pregunta que te ayude a entender mejor la fricción.",
      checkin_questions: "1. ¿Qué objeción o resistencia escuchaste hoy?\n2. ¿Qué descubriste al preguntar mejor?\n3. ¿Qué cambia con esa información?",
      ai_system_prompt: "Día 8 — Escuchar la fricción. Refuerza escucha útil y no defensiva.",
      template_name_whatsapp: "despertar_dia_08"
    },
    {
      day_number: 9, phase: :choose,
      title: "Hacer Visible el Avance",
      morning_template: "Lo que no se ve se enfría, {name}. Hoy elige una forma concreta de hacer visible un avance del cambio.",
      iareto_text: "IAReto Día 9: Destaca un avance, aprendizaje o señal de adopción en tu equipo o conversación de trabajo.",
      checkin_questions: "1. ¿Qué avance hiciste visible hoy?\n2. ¿Cómo reaccionaron los demás?\n3. ¿Qué efecto tuvo nombrarlo?",
      ai_system_prompt: "Día 9 — Hacer visible el avance. Refuerza reconocimiento útil, no celebración vacía.",
      template_name_whatsapp: "despertar_dia_09"
    },
    {
      day_number: 10, phase: :choose,
      title: "Elegir la Conducta Clave",
      morning_template: "{name}, último día de ELEGIR. Hoy identifica la conducta concreta que más mueve el cambio cuando sí aparece.",
      iareto_text: "IAReto Día 10: Repite esa conducta una vez más hoy y observa si conviene anclarla.",
      checkin_questions: "1. ¿Qué conducta clave elegiste repetir?\n2. ¿Qué la vuelve importante?\n3. ¿Quieres llevarla a la fase final?",
      ai_system_prompt: "Día 10 — Conducta clave del cambio. Prepara el anclaje final.",
      template_name_whatsapp: "despertar_dia_10"
    },
    {
      day_number: 11, phase: :anchor,
      title: "Ancla del Cambio",
      morning_template: "Entramos a ANCLAR, {name}. Elige una señal que te recuerde actuar a favor del cambio cuando vuelva la presión del día.",
      iareto_text: "IAReto Día 11: Define un ancla sencilla para sostener tu conducta clave: una reunión, una pregunta o un momento fijo.",
      checkin_questions: "1. ¿Cuál fue tu ancla del cambio?\n2. ¿Cuándo la activaste?\n3. ¿Qué ayudó a sostenerla?",
      ai_system_prompt: "Día 11 — Ancla del Cambio. Busca recordatorios aplicables en trabajo real.",
      template_name_whatsapp: "despertar_dia_11"
    },
    {
      day_number: 12, phase: :anchor,
      title: "Ritual de Coordinación",
      morning_template: "{name}, hoy decide un ritual pequeño que ayude a sostener el cambio: una pregunta fija, un cierre mejor o un seguimiento más visible.",
      iareto_text: "IAReto Día 12: Usa tu ritual una vez hoy y evalúa si tiene sentido repetirlo.",
      checkin_questions: "1. ¿Qué ritual probaste hoy?\n2. ¿Qué funcionó?\n3. ¿Qué ajustarías para sostenerlo?",
      ai_system_prompt: "Día 12 — Ritual de Coordinación. Favorece repetición y ajuste fino.",
      template_name_whatsapp: "despertar_dia_12"
    },
    {
      day_number: 13, phase: :anchor,
      title: "Carta al Cambio Saboteado",
      morning_template: "Penúltimo día, {name}. Hoy mira las formas en que antes saboteabas o enfriabas el cambio. No para culparte, sino para dejarlo más claro.",
      iareto_text: "IAReto Día 13: Escribe una breve carta mental a la versión tuya que decía 'después vemos esto'.",
      checkin_questions: "1. ¿Qué entendiste de esa versión tuya?\n2. ¿Qué decides no repetir?\n3. ¿Qué postura quieres sostener ahora?",
      ai_system_prompt: "Día 13 — Carta al Cambio Saboteado. Tono claro, no culposo.",
      template_name_whatsapp: "despertar_dia_13"
    },
    {
      day_number: 14, phase: :anchor,
      title: "Manifiesto del Cambio",
      morning_template: "Último día, {name}. Hoy observas cómo quieres contribuir al cambio más allá de estas dos semanas. Esta noche recibirás un manifiesto hecho con tus propias señales.",
      iareto_text: "IAReto Día 14: Ningún reto nuevo. Usa el día para notar dónde ya aparece tu nueva conducta.",
      checkin_questions: "1. ¿Qué conducta quieres sostener en el cambio?\n2. ¿Dónde necesitarás más disciplina para cuidarla?\n3. ¿Cuál será tu próximo recordatorio práctico?",
      ai_system_prompt: "Día 14 — Manifiesto del Cambio. Cierre práctico, sobrio y aplicable.",
      template_name_whatsapp: "despertar_dia_14"
    }
  ]
end

def productividad_days
  [
    {
      day_number: 1, phase: :see,
      title: "Inventario del Desgaste",
      morning_template: "Hola {name}. Durante 14 días vas a observar cómo trabajas de verdad. Hoy no intentes rendir mejor: solo nota dónde se te va foco, energía o atención.",
      iareto_text: "IAReto Día 1: Detecta tres momentos donde tu día se desordena: interrupciones, urgencias o cansancio.",
      checkin_questions: "1. ¿Dónde se te fue más foco hoy?\n2. ¿Qué drenó más tu energía?\n3. ¿Qué patrón se repitió?",
      ai_system_prompt: "Día 1 — Inventario del Desgaste. Fase VER. Ayuda a observar sin moralizar productividad.",
      template_name_whatsapp: "despertar_dia_01"
    },
    {
      day_number: 2, phase: :see,
      title: "Mapa de Interrupciones",
      morning_template: "Buen día, {name}. Hoy observa las interrupciones como dato: externas, internas o digitales. No pelees con ellas todavía.",
      iareto_text: "IAReto Día 2: Cada vez que pierdas foco, identifica si fue por una urgencia real, una distracción o una interrupción evitable.",
      checkin_questions: "1. ¿Qué tipo de interrupción predominó hoy?\n2. ¿Cuál fue la más costosa?\n3. ¿Qué te mostró eso sobre tu día real?",
      ai_system_prompt: "Día 2 — Mapa de Interrupciones. Refleja causas observables de pérdida de foco.",
      template_name_whatsapp: "despertar_dia_02"
    },
    {
      day_number: 3, phase: :see,
      title: "Hora Pico y Hora Valle",
      morning_template: "{name}, hoy mira tu energía como un recurso de diseño. ¿Cuándo estás más disponible? ¿Cuándo entras más fácil en modo reactivo?",
      iareto_text: "IAReto Día 3: Identifica tu hora pico y tu hora valle. Solo obsérvalas en relación con el trabajo que hiciste.",
      checkin_questions: "1. ¿Cuál fue tu mejor tramo de energía?\n2. ¿Cuál fue el más bajo?\n3. ¿Qué tipo de trabajo hiciste en cada uno?",
      ai_system_prompt: "Día 3 — Hora Pico y Hora Valle. Refuerza observación de energía aplicada al trabajo.",
      template_name_whatsapp: "despertar_dia_03"
    },
    {
      day_number: 4, phase: :see,
      title: "Prioridad vs. Reacción",
      morning_template: "Cuarto día, {name}. Hoy observa la diferencia entre trabajar por prioridad y trabajar por reacción. No cambies el día: solo nótalo.",
      iareto_text: "IAReto Día 4: En dos momentos del día, pregúntate: '¿estoy eligiendo o reaccionando?'.",
      checkin_questions: "1. ¿Dónde estuviste más reactivo hoy?\n2. ¿Dónde elegiste con más intención?\n3. ¿Qué diferencia notaste?",
      ai_system_prompt: "Día 4 — Prioridad vs Reacción. Ayuda a contrastar intención y arrastre del día.",
      template_name_whatsapp: "despertar_dia_04"
    },
    {
      day_number: 5, phase: :see,
      title: "Foto de tu Productividad Real",
      morning_template: "Quinto día, {name}. Ya tienes señales suficientes. Hoy arma una foto realista de cómo estás trabajando: qué te ayuda, qué te dispersa y qué te desgasta.",
      iareto_text: "IAReto Día 5: Resume tu forma actual de trabajar en una sola frase honesta.",
      checkin_questions: "1. ¿Cómo resumirías hoy tu productividad real?\n2. ¿Qué parte de esa foto te pesa más?\n3. ¿Qué vale la pena conservar?",
      ai_system_prompt: "Día 5 — Cierre fase VER en productividad. Sintetiza sin juzgar.",
      template_name_whatsapp: "despertar_dia_05"
    },
    {
      day_number: 6, phase: :choose,
      title: "Micro-elección de Foco",
      morning_template: "{name}, comienza ELEGIR. Hoy el objetivo no es hacer más, sino proteger un pequeño bloque de foco con intención.",
      iareto_text: "IAReto Día 6: Protege un bloque breve para una tarea importante y define antes qué sería un buen cierre para ese bloque.",
      checkin_questions: "1. ¿Qué bloque de foco protegiste hoy?\n2. ¿Qué ayudó a sostenerlo?\n3. ¿Qué intentó romperlo?",
      ai_system_prompt: "Día 6 — Micro-elección de foco. Refuerza protección de atención sin rigidez.",
      template_name_whatsapp: "despertar_dia_06"
    },
    {
      day_number: 7, phase: :choose,
      title: "Cerrar Mejor, no Más Tarde",
      morning_template: "Hoy, {name}, prueba cerrar mejor una tarea en vez de seguir estirándola. A veces el desgaste viene de lo que queda abierto.",
      iareto_text: "IAReto Día 7: Elige una tarea o conversación pendiente y dale un cierre concreto hoy.",
      checkin_questions: "1. ¿Qué lograste cerrar hoy?\n2. ¿Qué alivio o espacio dejó?\n3. ¿Qué te mostró eso sobre tu carga actual?",
      ai_system_prompt: "Día 7 — Cerrar mejor. Refleja alivio, liberación o resistencia a cerrar.",
      template_name_whatsapp: "despertar_dia_07"
    },
    {
      day_number: 8, phase: :choose,
      title: "Una Prioridad Visible",
      morning_template: "{name}, hoy elige una sola prioridad visible para ti antes de que el día se llene. No tiene que ser épica; sí concreta.",
      iareto_text: "IAReto Día 8: Formula tu prioridad del día en una línea y revísala una vez al mediodía.",
      checkin_questions: "1. ¿Cuál fue tu prioridad visible hoy?\n2. ¿Te ayudó a decidir mejor?\n3. ¿Qué se interpuso?",
      ai_system_prompt: "Día 8 — Prioridad visible. Busca claridad, no perfección.",
      template_name_whatsapp: "despertar_dia_08"
    },
    {
      day_number: 9, phase: :choose,
      title: "Bajar una Fuente de Ruido",
      morning_template: "Hoy, {name}, no intentes limpiar todo el ruido. Solo baja una fuente concreta de dispersión.",
      iareto_text: "IAReto Día 9: Reduce una fuente de ruido por un tramo del día: notificaciones, multitarea o una consulta no urgente.",
      checkin_questions: "1. ¿Qué fuente de ruido redujiste hoy?\n2. ¿Qué pasó al hacerlo?\n3. ¿Vale la pena repetirlo mañana?",
      ai_system_prompt: "Día 9 — Bajar una fuente de ruido. Refuerza cambio pequeño con efecto real.",
      template_name_whatsapp: "despertar_dia_09"
    },
    {
      day_number: 10, phase: :choose,
      title: "Elegir tu Mejor Modo",
      morning_template: "{name}, último día de ELEGIR. Hoy repite a propósito una conducta que te haya ayudado a trabajar con más foco o menos desgaste.",
      iareto_text: "IAReto Día 10: Repite una conducta útil que haya aparecido esta semana y observa si quieres anclarla.",
      checkin_questions: "1. ¿Qué conducta elegiste repetir?\n2. ¿Qué la vuelve valiosa?\n3. ¿Cuál quieres llevar a la última fase?",
      ai_system_prompt: "Día 10 — Elegir tu mejor modo. Prepara el anclaje final.",
      template_name_whatsapp: "despertar_dia_10"
    },
    {
      day_number: 11, phase: :anchor,
      title: "Ancla de Foco",
      morning_template: "Entramos a ANCLAR, {name}. Elige una señal simple para recordarte cómo quieres trabajar cuando el día se desordene.",
      iareto_text: "IAReto Día 11: Define un ancla de foco: una pregunta, un gesto o un momento fijo antes de empezar algo importante.",
      checkin_questions: "1. ¿Cuál fue tu ancla de foco?\n2. ¿Cuándo la usaste?\n3. ¿Qué te permitió sostener?",
      ai_system_prompt: "Día 11 — Ancla de Foco. Busca recordatorio concreto y aplicable.",
      template_name_whatsapp: "despertar_dia_11"
    },
    {
      day_number: 12, phase: :anchor,
      title: "Ritmo de Energía",
      morning_template: "{name}, hoy usa mejor tu ritmo. No se trata de controlar todo, sino de respetar un poco más cuándo estás mejor para lo importante.",
      iareto_text: "IAReto Día 12: Vincula tu ancla a un momento en que sueles perder foco o energía y pruébala ahí.",
      checkin_questions: "1. ¿En qué momento probaste tu ancla hoy?\n2. ¿Funcionó mejor en un tramo específico?\n3. ¿Qué ajustarías?",
      ai_system_prompt: "Día 12 — Ritmo de Energía. Refuerza ajuste realista y sostenible.",
      template_name_whatsapp: "despertar_dia_12"
    },
    {
      day_number: 13, phase: :anchor,
      title: "Carta al Modo Reactivo",
      morning_template: "Penúltimo día, {name}. Hoy mira la versión tuya que corría detrás de todo. No para pelear con ella, sino para dejarla mejor entendida.",
      iareto_text: "IAReto Día 13: Escribe una breve carta mental a tu modo reactivo: qué intentaba resolver, qué costo tenía y qué eliges ahora.",
      checkin_questions: "1. ¿Qué comprendiste de tu modo reactivo?\n2. ¿Qué decides soltar?\n3. ¿Cómo nombrarías tu nueva forma de trabajar?",
      ai_system_prompt: "Día 13 — Carta al Modo Reactivo. Tono sereno y de apropiación.",
      template_name_whatsapp: "despertar_dia_13"
    },
    {
      day_number: 14, phase: :anchor,
      title: "Manifiesto de Productividad Sostenible",
      morning_template: "Último día, {name}. Hoy no hay un reto nuevo. Observa cómo quieres trabajar más allá de estas dos semanas y prepárate para recibir tu manifiesto.",
      iareto_text: "IAReto Día 14: Ningún reto nuevo. Usa el día para notar qué conducta vale la pena conservar.",
      checkin_questions: "1. ¿Qué conducta quieres conservar?\n2. ¿Dónde necesitarás cuidarla más?\n3. ¿Qué recordatorio práctico te ayudará a sostenerla?",
      ai_system_prompt: "Día 14 — Manifiesto de Productividad Sostenible. Cierre concreto, no moralista.",
      template_name_whatsapp: "despertar_dia_14"
    }
  ]
end

PROGRAM_DEFINITIONS.each do |definition|
  seed_program!(definition)
end

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  admin = AdminUser.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  admin.password = ENV["ADMIN_PASSWORD"]
  admin.name ||= ENV["ADMIN_NAME"].presence || "Admin"
  admin.save!
  puts "Admin seeded: #{admin.email}"
else
  puts "Skipping admin seed (set ADMIN_EMAIL and ADMIN_PASSWORD)"
end
