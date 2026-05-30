# db/seeds/demo_data.rb

puts "--- Seeding Demo Data ---"

# Deletes existing demo participants to guarantee clean idempotency
[ "+56911111111", "+56922222222", "+56933333333", "+56944444444", "+56955555555", "+56966666666", "+56977777777", "+56988888888" ].each do |phone|
  Participant.find_by(phone_e164: phone)&.destroy
end
UnknownInbound.where(wamid: [ "wamid.seed_unknown_1", "wamid.seed_unknown_2" ]).destroy_all


# 1. Impulso Liderazgo en Acción
prog_liderazgo = Program.find_by!(slug: "impulso-liderazgo-en-accion")
camila = Participant.create!(
  name: "Camila Muñoz",
  phone_e164: "+56911111111",
  email: "camila.munoz@nexus.io",
  status: :completed,
  current_day: 15,
  timezone: "America/Santiago",
  company: "Fintech Nexus",
  role: "Product Owner Sr.",
  initial_pattern: "Suelo sobre-controlar el avance técnico de mi equipo porque siento que si no estoy encima de cada detalle, las cosas no se van a entregar a tiempo o con calidad. Esto me deja sin tiempo para la estrategia y cansa a mis desarrolladores.",
  enrolled_at: 15.days.ago,
  started_at: 15.days.ago,
  completed_at: Date.current.beginning_of_day + 8.hours,
  energy_map: {
    "lunes" => [ 3, 4 ], "martes" => [ 2, 4 ], "miercoles" => [ 2, 3 ],
    "jueves" => [ 3, 4 ], "viernes" => [ 4, 5 ]
  }
)

camila_responses = {
  1 => {
    response: "1. En la reunión diaria de la mañana, interrumpí a dos devs para decirles exactamente cómo resolver un bug en vez de dejar que propusieran ellos. 2. En una sesión de feedback 1a1 por la tarde. Ahí sí escuché. 3. Me di cuenta de que cuando el tiempo apremia me vuelvo muy controladora y directiva.",
    summary: "El participante observó una reacción impulsiva y controladora en la reunión diaria ante la presión del tiempo, logrando mayor presencia y escucha durante la tarde.",
    pattern: "Control por urgencia"
  },
  2 => {
    response: "1. Postergué hablar con el diseñador sobre un retraso porque sé que es conflictivo y preferí ver otras cosas más operativas. 2. Evité la confrontación. 3. El costo es que el sprint se va a retrasar dos días más por no alinearlo a tiempo.",
    summary: "Se observó evitación activa de una conversación difícil con un diseñador por temor al conflicto, lo que genera retraso acumulado en el sprint.",
    pattern: "Evitación del conflicto"
  },
  3 => {
    response: "1. Hoy se cayó un servidor y mi reacción inmediata fue buscar culpables en Slack en vez de ayudar a solucionar. 2. Reaccioné a la defensiva y presionando al equipo. 3. El efecto en el equipo fue de tensión y silencio, nadie quería proponer nada.",
    summary: "El participante reaccionó buscando culpables y presionando al equipo ante una caída de servidor, provocando tensión y retracción comunicativa.",
    pattern: "Buscar culpables bajo presión"
  },
  4 => {
    response: "1. Creo que el equipo me percibió como una máquina apurada hoy. Estaba contestando rápido e ignorando saludos cordiales. 2. No, quería dar seguridad. 3. Me dice que la presión externa anula mis intenciones de ser una líder cercana.",
    summary: "El participante percibe que proyectó urgencia y frialdad hacia el equipo debido a la carga externa, distanciándose de su estilo de liderazgo ideal.",
    pattern: "Filtro de urgencia hacia el equipo"
  },
  5 => {
    response: "1. Mi liderazgo actual se resume en 'correr para apagar incendios controlando todo lo que se pueda'. 2. Me incomoda ver que no confío en mi equipo. 3. Sí vale la pena conservar mi capacidad de resolver rápido y ponerme al frente.",
    summary: "Cierre de fase VER: El participante diagnostica un liderazgo reactivo basado en la desconfianza del equipo pero reconoce su habilidad resolutiva en crisis.",
    pattern: "Liderazgo bombero"
  },
  6 => {
    response: "1. Elegí no opinar en los primeros 10 minutos de la sesión de diseño técnico y dejé que el equipo propusiera. 2. Lograron acordar una buena arquitectura ellos solos. Sentí un poco de ansiedad pero funcionó. 3. Apareció mi impulso de rellenar los silencios.",
    summary: "Inicio de fase ELEGIR: El participante practicó el silencio consciente al inicio de una reunión, permitiendo autonomía y co-diseño en el equipo.",
    pattern: "Silencio habilitador"
  },
  7 => {
    response: "1. Logré hacer la pausa de 3 segundos en una reunión cuando me dieron una mala noticia de plazos. 2. Evitó que les reclamara en público. 3. Conversamos de forma constructiva para redefinir el plan en vez de enojarme.",
    summary: "El participante implementó con éxito la pausa física antes de responder a un retraso, derivando en una planificación colaborativa y no reactiva.",
    pattern: "Regulación emocional"
  },
  8 => {
    response: "1. Le pedí a Lucas un reporte de avance. En vez de decirle 'mándamelo luego', le pedí específicamente el estado de la API para mañana a las 4 PM. 2. Se vio más tranquilo. Me dijo de inmediato que tenía un bloqueo con el servidor y lo resolvimos juntos. 3. Que al ser clara y dar espacio, la gente colabora.",
    summary: "El participante definió expectativas claras en el seguimiento técnico, lo que facilitó la revelación de un bloqueo técnico por parte del desarrollador.",
    pattern: "Seguimiento claro y habilitante"
  },
  9 => {
    response: "1. Agendé una sesión corta de 15 minutos con el diseñador conflictivo para mañana. Abrí el contexto amigablemente diciendo que quería apoyarlo a destrabar el retraso. 2. Tener un foco de colaboración y no de reclamo. 3. Que es mejor abordar el tema en privado y temprano.",
    summary: "El participante dio un paso concreto hacia la conversación pendiente al agendar una sesión privada con enfoque cooperativo.",
    pattern: "Abordar temprano con empatía"
  },
  10 => {
    response: "1. Repetí el hábito de pausar antes de hablar en la planificación del sprint. 2. La diferencia fue que el ambiente fue mucho más colaborativo y el equipo se sintió más dueño del compromiso. 3. Quiero anclar el preguntar antes de decidir.",
    summary: "Cierre de fase ELEGIR: Se consolidó el hábito de la pausa en espacios grupales, promoviendo mayor sentido de pertenencia y compromiso en el equipo.",
    pattern: "Pausa grupal deliberada"
  },
  11 => {
    response: "1. Mi ancla fue respirar hondo antes de abrir la sala de Zoom. 2. La usé en 3 reuniones de la mañana. 3. Me sirvió para entrar calmada y no empezar la reunión exigiendo reportes de forma agresiva.",
    summary: "Fase ANCLAR: El participante define como ancla la respiración profunda antes de ingresar a videoconferencias, regulando su tono de entrada.",
    pattern: "Ancla de entrada a reunión"
  },
  12 => {
    response: "1. Asocié mi ancla al momento del Daily Standup. 2. Funcionó bien porque me recordó escuchar primero en vez de imponer la agenda del día de inmediato. 3. Quiero sostenerlo.",
    summary: "El participante enlazó su ancla conductual a un hito recurrente (Daily), logrando balancear su participación e incentivar la voz del equipo.",
    pattern: "Anclaje en rito diario"
  },
  13 => {
    response: "1. Le agradecí a mi versión reactiva por su intención de proteger el proyecto de fallas. 2. Decidí dejar atrás el control excesivo y la urgencia innecesaria. 3. Nombro mi nueva forma de liderar como 'Liderazgo Habilitador'.",
    summary: "El participante realiza una autocompasión constructiva respecto a su conducta controladora del pasado y declara su identidad como líder habilitadora.",
    pattern: "Identidad: Líder Habilitador"
  },
  14 => {
    response: "1. Quiero conservar la conducta de preguntar '¿qué necesitas para lograrlo?' en vez de dar instrucciones directas. 2. Necesito cuidarla en los cierres de sprint. 3. Mi recordatorio será un post-it físico en la pantalla que diga 'Pregunta, no resuelvas'.",
    summary: "Cierre de programa: Definición de hábito permanente y estrategia de recordatorio físico para sortear momentos de alta presión.",
    pattern: "Hábito definitivo: Indagación apreciativa"
  }
}

camila_manifesto = <<~TEXT
Camila, aquí tienes tu Manifiesto de Liderazgo en Acción:

Eres una líder que construye autonomía a través de la claridad. Has aprendido a ver que tu impulso de control surge de la ansiedad por el tiempo, pero que tu verdadera efectividad aparece cuando dejas de resolver y empiezas a preguntar.

Tus anclas clave:
1. Al iniciar un seguimiento, define expectativa exacta y pregunta: '¿Qué necesitas para lograrlo?'.
2. En momentos de presión en el cierre de sprint, respira 3 segundos antes de intervenir.

Recuerda: Tu equipo no necesita que les digas el 'cómo', sino que asegures el 'para qué'. Confía en la capacidad que has ayudado a desarrollar.
TEXT

# 2. Impulso Cambio en Acción
prog_cambio = Program.find_by!(slug: "impulso-cambio-en-accion")
mateo = Participant.create!(
  name: "Mateo Valenzuela",
  phone_e164: "+56922222222",
  email: "mateo.valenzuela@logistica.cl",
  status: :completed,
  current_day: 15,
  timezone: "America/Santiago",
  company: "Logística Austral",
  role: "Líder de Operaciones",
  initial_pattern: "Me cuesta aceptar los nuevos protocolos del sistema SAP que implementaron. Siento que alargan mi trabajo diario, así que tiendo a esquivarlos, usar planillas Excel por fuera y quejarme con mi equipo de que el sistema nuevo es inútil.",
  enrolled_at: 15.days.ago,
  started_at: 15.days.ago,
  completed_at: Date.current.beginning_of_day + 8.hours,
  energy_map: {
    "lunes" => [ 4, 4 ], "martes" => [ 3, 4 ], "miercoles" => [ 2, 3 ],
    "jueves" => [ 3, 3 ], "viernes" => [ 4, 4 ]
  }
)

mateo_responses = {
  1 => {
    response: "1. Avanzó cuando vi que un supervisor usó SAP directamente para registrar una salida. 2. Se frenó cuando yo mismo usé el Excel para no perder tiempo buscando el código. 3. Mi conducta de comodidad. El Excel es más rápido para mí en el momento, aunque duplique trabajo después.",
    summary: "El participante observó avance en su equipo pero evasión propia, volviendo al Excel por inmediatez operativa.",
    pattern: "Evasión por comodidad"
  },
  2 => {
    response: "1. Detecté resistencia en el equipo al ingresar las mermas. 2. Se quejaban de que tiene demasiados campos obligatorios. 3. La resistencia viene de que sienten que es trabajo administrativo extra sin valor para ellos.",
    summary: "Se detectó resistencia grupal en bodegas al ingreso de mermas, argumentando burocracia excesiva y falta de propósito en la tarea.",
    pattern: "Resistencia por falta de propósito"
  },
  3 => {
    response: "1. Se trabaron los despachos porque el sistema no reconocía un código. 2. Afectó al chofer del camión que tuvo que esperar 30 minutos. 3. Se repite porque no hay una guía rápida de errores comunes para el operador de turno.",
    summary: "Una falla de datos trabó un despacho y retrasó la ruta. El participante identificó falta de herramientas de resolución rápida en planta.",
    pattern: "Bloqueo por falta de soporte"
  },
  4 => {
    response: "1. Vi que una operaria ayudaba a otro a buscar el código correcto en SAP. 2. Fue una buena señal de colaboración. 3. Me ayudó a ver que si nos apoyamos, la curva de aprendizaje es más corta y no depende solo de TI.",
    summary: "El participante observó ayuda mutua espontánea en el equipo, disminuyendo la dependencia de soporte centralizado.",
    pattern: "Colaboración comunitaria"
  },
  5 => {
    response: "1. Hoy diría que 'el cambio avanza a tropezones porque seguimos con un pie en el Excel'. 2. Lo más difícil es la lentitud inicial. 3. Vale la pena porque la información integrada nos evitará reclamos de clientes.",
    summary: "Cierre de fase VER: Diagnóstico de una operación híbrida que resiste la lentitud del inicio pero valora la precisión de los datos futuros.",
    pattern: "Operación paralela"
  },
  6 => {
    response: "1. Elegí automatizar un reporte de stock en SAP en vez de compilarlo a mano. 2. Tomó 15 minutos configurarlo pero me va a ahorrar 1 hora cada viernes. 3. Que es mejor invertir tiempo en entender la herramienta.",
    summary: "Inicio de fase ELEGIR: El participante automatizó una tarea utilizando el nuevo sistema, logrando un ahorro de tiempo neto semanal.",
    pattern: "Inversión en aprendizaje"
  },
  7 => {
    response: "1. Aclaré las expectativas de registro con el equipo de bodega. 2. Al explicarles que registrar mermas ayuda a planificar compras, entendieron el sentido del cambio y mostraron menos quejas. 3. Que la claridad baja la resistencia.",
    summary: "El participante transparentó el propósito del registro de mermas con su equipo, logrando mayor adopción voluntaria.",
    pattern: "Alineación de propósito"
  },
  8 => {
    response: "1. Sentí frustración cuando el sistema me bloqueó por un código de inventario. Descubrí que la fricción es que no tenemos actualizadas las ubicaciones de bodega. 2. El problema no es SAP, es nuestro orden físico. 3. Cambia que ya no le echo la culpa a SAP.",
    summary: "El participante distinguió la fricción del sistema de un desorden operativo físico preexistente en bodega.",
    pattern: "Separar herramienta de proceso"
  },
  9 => {
    response: "1. Hice visible el avance mostrando en la pizarra de la oficina que los errores de despacho bajaron un 15% usando el sistema. 2. El equipo se sintió motivado al ver que el esfuerzo da frutos. 3. Que el progreso visible ayuda a sostener la marcha.",
    summary: "El participante comunicó métricas de éxito (reducción de errores de despacho), fortaleciendo la motivación del equipo.",
    pattern: "Celebrar progreso medible"
  },
  10 => {
    response: "1. Elegí registrar todos los despachos del día directo en la plataforma. 2. Me di cuenta de que ya no me demoro tanto como la primera semana y que la información queda limpia. 3. Quiero consolidar esto como mi único estándar.",
    summary: "Cierre de fase ELEGIR: El participante opera el día completo bajo el nuevo protocolo, verificando la reducción de la fricción inicial.",
    pattern: "Consolidación de uso"
  },
  11 => {
    response: "1. Mi ancla fue colocar una pestaña fija del sistema en mi navegador y ocultar el acceso directo de Excel. 2. Me sirvió para no abrir la planilla de forma automática por la mañana. 3. Ayudó a evitar el gatillazo mental del hábito anterior.",
    summary: "Fase ANCLAR: El participante modificó su entorno digital para eliminar disparadores del hábito anterior (Excel).",
    pattern: "Rediseño de entorno digital"
  },
  12 => {
    response: "1. Vinculé mi ancla al momento de recibir la planilla de recepción de camiones. 2. Funcionó bien porque me forzó a digitar directo en el sistema en vez de acumular papel en mi escritorio. 3. Evita que procrastine el registro.",
    summary: "El participante vinculó el registro digital a la llegada física del transportista, previniendo la acumulación de datos pendientes.",
    pattern: "Anclaje a evento físico"
  },
  13 => {
    response: "1. Comprendí que mi yo reactivo usaba Excel por miedo a fallar y retrasar al cliente. 2. Decido dejar atrás la evasión tecnológica y la queja destructiva. 3. Ahora nombro mi postura como 'Eficiencia Integrada'.",
    summary: "El participante resignifica su evitación pasada como un mecanismo de protección de tiempos y declara su nueva postura.",
    pattern: "Identidad: Eficiencia Integrada"
  },
  14 => {
    response: "1. Quiero sostener el uso del sistema como único canal para despachos. 2. Necesito disciplina en los horarios punta de carga. 3. Mi recordatorio será cerrar la ventana de Excel por completo de mi computador a las 16:00.",
    summary: "Cierre de programa: Selección de la conducta clave a sostener y establecimiento de guardrail para momentos de urgencia de la tarde.",
    pattern: "Hábito definitivo: Monocanal oficial"
  }
}

mateo_manifesto = <<~TEXT
Mateo, aquí está tu Manifiesto del Cambio en Acción:

Eres un líder que impulsa el cambio resolviendo problemas de raíz, no buscando culpables. Lograste ver que tu resistencia inicial al nuevo sistema era una respuesta a un desorden previo en la información, no un problema tecnológico.

Tus anclas:
1. Ante un bloqueo del sistema, en lugar de abrir Excel, tómate 2 minutos para documentar la causa raíz.
2. Cierra tus planillas auxiliares a las 16:00 para asegurar que el cierre del día ocurra en la plataforma oficial.

Sigue liderando con el ejemplo. Tu equipo adopta lo que te ve usar con convicción.
TEXT

# 3. Impulso Productividad Sostenible
prog_productividad = Program.find_by!(slug: "impulso-productividad-sostenible")
sofia = Participant.create!(
  name: "Sofía Rivas",
  phone_e164: "+56933333333",
  email: "sofia.rivas@saas.com",
  status: :completed,
  current_day: 15,
  timezone: "America/Santiago",
  company: "SaaS Solutions",
  role: "Key Account Manager",
  initial_pattern: "Siento que vivo en modo bombero, apagando incendios en Teams, WhatsApp y correo. Respondo todo de inmediato porque me da pánico que un cliente de ventas piense que no le presto atención, pero termino mi día a las 9 PM agotada y sintiendo que no avancé en mis propuestas importantes.",
  enrolled_at: 15.days.ago,
  started_at: 15.days.ago,
  completed_at: Date.current.beginning_of_day + 8.hours,
  energy_map: {
    "lunes" => [ 3, 3 ], "martes" => [ 2, 3 ], "miercoles" => [ 2, 2 ],
    "jueves" => [ 3, 4 ], "viernes" => [ 4, 5 ]
  }
)

sofia_responses = {
  1 => {
    response: "1. Se me fue el foco contestando chats de Teams que no eran urgentes mientras redactaba una propuesta de cliente. 2. Una llamada sorpresa de un cliente que duró 40 minutos para un tema que se resolvía por correo. 3. El patrón es estar con 5 pestañas de chat abiertas y responder al segundo.",
    summary: "El participante experimentó una alta fragmentación del foco por notificaciones de chat y llamadas no planificadas, respondiendo de forma instantánea.",
    pattern: "Reactividad digital inmediata"
  },
  2 => {
    response: "1. Predominaron las interrupciones digitales de Slack y Teams. 2. La más costosa fue la de un colega preguntando algo que estaba en el manual. 3. Me mostró que paso el día resolviendo dudas ajenas y dejando lo mío para el final del día.",
    summary: "El participante identifica que las consultas de sus pares constituyen interrupciones severas, subordinando sus prioridades personales.",
    pattern: "Interrupción por soporte interno"
  },
  3 => {
    response: "1. Mi mejor energía fue entre 9 y 11 AM, donde preparé una cotización difícil. 2. El valle fue a las 3 PM después de almorzar. 3. Trabajé la cotización con energía y en la tarde entré en modo reactivo a borrar correos sin pensar.",
    summary: "El participante reporta alta energía cognitiva por la mañana y fatiga post-almuerzo, donde opera mecánicamente limpiando su buzón.",
    pattern: "Asignación de energía por bloques"
  },
  4 => {
    response: "1. Estuve muy reactiva en la tarde contestando correos viejos en vez de avanzar en la propuesta comercial. 2. Cuando elijo con intención me siento en control del día. 3. Que la reactividad me produce cansancio acumulado.",
    summary: "Se observa el contraste entre la sensación de control al trabajar proactivamente y el desgaste de reaccionar al buzón de entrada.",
    pattern: "Reactividad vs Elección"
  },
  5 => {
    response: "1. Mi productividad real es 'reactiva y fragmentada por el pánico a no estar disponible'. 2. Me pesa terminar tarde y cansada. 3. Quiero conservar mi compromiso y velocidad para responder a los clientes importantes.",
    summary: "Cierre de fase VER: El participante asume un patrón de inmediatez digital derivado del temor a desatender clientes, pero desea conservar su orientación al servicio.",
    pattern: "Reactividad por pánico de servicio"
  },
  6 => {
    response: "1. Protegí un bloque de 40 minutos en la mañana para estructurar una presentación. Puse el estado en Teams como 'No molestar'. 2. Avancé el doble de lo normal y sentí que logré concentrarme bien. 3. La tentación interna de abrir la pestaña de chat.",
    summary: "Inicio de fase ELEGIR: Implementación exitosa de un bloque de foco matutino mediante cambio de estado en Teams, sorteando la tentación de interrupción.",
    pattern: "Bloqueo de foco con guardrail"
  },
  7 => {
    response: "1. Logré cerrar la propuesta de Retail que llevaba tres días abierta. 2. Sentí un gran alivio y espacio mental. 3. Me mostró que arrastrar tareas a medio hacer me agota más de lo que creo.",
    summary: "El participante experimentó liberación de carga cognitiva al completar una tarea pendiente prolongada, notando el desgaste de los pendientes abiertos.",
    pattern: "Alivio por cierre de pendientes"
  },
  8 => {
    response: "1. Mi prioridad fue terminar la propuesta del cliente Retail. 2. Me ayudó a restarme de una reunión informativa a las 11 AM. 3. Se interpuso la tentación de ver las notificaciones parpadeantes en mi barra de tareas.",
    summary: "El participante utilizó su prioridad declarada como filtro para rechazar una reunión no prioritaria, aunque persistió la tentación visual de notificaciones.",
    pattern: "Filtro de prioridades"
  },
  9 => {
    response: "1. Apagué las notificaciones de escritorio de Outlook por toda la tarde. 2. Logré redactar tres correos importantes sin interrupciones visuales. 3. Definitivamente lo voy a repetir mañana para proteger la redacción.",
    summary: "El participante desactivó las alertas visuales de correo, logrando fluidez de redacción y planeando replicar la conducta.",
    pattern: "Eliminación de alertas visuales"
  },
  10 => {
    response: "1. Repetí el hábito de bloquear mi agenda para trabajo enfocado. 2. Es muy valioso porque me permite avanzar en lo importante temprano y dejar la tarde para reuniones rápidas. 3. Quiero consolidar dos bloques fijos al día.",
    summary: "Cierre de fase ELEGIR: Consolidación de bloques de agenda blindados en horario matutino para optimizar la toma de decisiones complejas.",
    pattern: "Time-blocking matutino"
  },
  11 => {
    response: "1. Mi ancla fue poner el teléfono boca abajo en mi escritorio y cerrar la pestaña de Teams durante los bloques de foco. 2. Me permitió sostener la concentración por 50 minutos seguidos. 3. Logré un avance rápido.",
    summary: "Fase ANCLAR: El participante define barreras físicas (teléfono boca abajo) e informáticas (cerrar Teams) para proteger su atención.",
    pattern: "Ancla de desconexión selectiva"
  },
  12 => {
    response: "1. Probé mi ancla a las 4 PM, que es cuando mi energía decae y me tiento con redes sociales o chats. 2. Funcionó a medias, necesito más disciplina en ese tramo de fatiga. 3. Debo buscar un descanso activo en vez de distraerme en pantalla.",
    summary: "El participante aplicó el ancla en su hora de menor energía, identificando la necesidad de descansos físicos en lugar de distracción digital pasiva.",
    pattern: "Fatiga y descanso activo"
  },
  13 => {
    response: "1. Comprendí que mi yo reactivo buscaba aprobación inmediata de otros a costa de mi salud y foco de ventas. 2. Decido soltar el estar 100% disponible al instante. 3. Nombro mi nueva forma de trabajar como 'Foco Sostenible'.",
    summary: "El participante reconoce el costo de la validación externa inmediata y opta por una identidad de foco sostenible y dosificado.",
    pattern: "Identidad: Foco Sostenible"
  },
  14 => {
    response: "1. Quiero conservar los bloques de foco sin notificaciones. 2. Necesito cuidarla en la mañana cuando la ansiedad por revisar correos sube. 3. Mi recordatorio será cerrar las apps al iniciar el bloque.",
    summary: "Cierre de programa: Selección de bloques de desconexión controlada matutinos como hábito definitivo y barreras de inicio como recordatorio.",
    pattern: "Hábito definitivo: Desconexión dosificada"
  }
}

sofia_manifesto = <<~TEXT
Sofía, aquí tienes tu Manifiesto de Productividad Sostenible:

Eres una profesional que valora su foco y entiende que estar disponible al instante no equivale a ser efectiva. Has aprendido que el pánico a no responder de inmediato es una creencia que fragmenta tu día y sabotea la calidad de tu trabajo comercial.

Tus anclas consolidadas:
1. Al iniciar tus propuestas clave, cierra Teams y Outlook. Proscribe los avisos visuales.
2. Revisa tu papel de 'Prioridad del Día' a las 12:00 y pregúntate si estás decidiendo o reaccionando.

Sostener tus límites no es desatender a tus clientes; es darles tu mejor versión. Protege tu energía para que tu negocio crezca contigo.
TEXT

# Helper to populate conversation and daily reports for a participant
def populate_demo_history!(participant, program, responses, manifesto_text)
  puts "Seeding history for #{participant.name}..."

  # Create Day 0 / Welcome interactions
  welcome_content = "¡Hola #{participant.name}! Bienvenido/a a #{program.name}. Escríbeme: #{program.manifesto.split("\n").last}" # best effort fallback

  # Welcome out
  Conversation.create!(
    participant: participant,
    day_number: 0,
    moment: :welcome,
    role: :assistant,
    body: welcome_content,
    created_at: 15.days.ago.beginning_of_day + 10.hours,
    sent_at: 15.days.ago.beginning_of_day + 10.hours,
    delivered_at: 15.days.ago.beginning_of_day + 10.hours + 2.seconds,
    read_at: 15.days.ago.beginning_of_day + 10.hours + 1.minute
  )

  # Welcome response in
  Conversation.create!(
    participant: participant,
    day_number: 0,
    moment: :welcome,
    role: :user,
    body: participant.initial_pattern,
    created_at: 15.days.ago.beginning_of_day + 10.hours + 5.minutes,
    sent_at: 15.days.ago.beginning_of_day + 10.hours + 5.minutes,
    delivered_at: 15.days.ago.beginning_of_day + 10.hours + 5.minutes + 1.second,
    read_at: 15.days.ago.beginning_of_day + 10.hours + 5.minutes + 1.second
  )

  # Create Days 1 to 14
  (1..14).each do |day|
    day_content = DayContent.find_by!(program: program, day_number: day)
    day_data = responses[day]

    base_time = (15 - day).days.ago

    # 1. morning_wake (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :morning_wake,
      role: :assistant,
      body: day_content.morning_template.gsub("{name}", participant.name),
      created_at: base_time.beginning_of_day + 7.hours + 30.minutes,
      sent_at: base_time.beginning_of_day + 7.hours + 30.minutes,
      delivered_at: base_time.beginning_of_day + 7.hours + 30.minutes + 2.seconds,
      read_at: base_time.beginning_of_day + 7.hours + 35.minutes
    )

    # 2. iareto (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :iareto,
      role: :assistant,
      body: day_content.iareto_text,
      created_at: base_time.beginning_of_day + 8.hours,
      sent_at: base_time.beginning_of_day + 8.hours,
      delivered_at: base_time.beginning_of_day + 8.hours + 2.seconds,
      read_at: base_time.beginning_of_day + 8.hours + 10.minutes
    )

    # 3. checkin_question (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :checkin_question,
      role: :assistant,
      body: day_content.checkin_questions,
      created_at: base_time.beginning_of_day + 20.hours,
      sent_at: base_time.beginning_of_day + 20.hours,
      delivered_at: base_time.beginning_of_day + 20.hours + 2.seconds,
      read_at: base_time.beginning_of_day + 20.hours + 15.minutes
    )

    # 4. checkin_response (user)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :checkin_response,
      role: :user,
      body: day_data[:response],
      created_at: base_time.beginning_of_day + 20.hours + 20.minutes,
      sent_at: base_time.beginning_of_day + 20.hours + 20.minutes,
      delivered_at: base_time.beginning_of_day + 20.hours + 20.minutes + 1.second,
      read_at: base_time.beginning_of_day + 20.hours + 20.minutes + 1.second
    )

    # 5. DailyReport
    DailyReport.create!(
      participant: participant,
      day_number: day,
      raw_text: day_data[:response],
      ai_summary: day_data[:summary],
      ai_key_pattern: day_data[:pattern],
      reported_at: base_time.beginning_of_day + 20.hours + 21.minutes,
      created_at: base_time.beginning_of_day + 20.hours + 21.minutes,
      updated_at: base_time.beginning_of_day + 20.hours + 21.minutes
    )
  end

  # Create Day 15 Manifesto
  Conversation.create!(
    participant: participant,
    day_number: 15,
    moment: :manifesto,
    role: :assistant,
    body: manifesto_text,
    created_at: Date.current.beginning_of_day + 8.hours,
    sent_at: Date.current.beginning_of_day + 8.hours,
    delivered_at: Date.current.beginning_of_day + 8.hours + 2.seconds,
    read_at: Date.current.beginning_of_day + 8.hours + 5.minutes
  )

  participant.update!(closing_manifesto: manifesto_text)
end

populate_demo_history!(camila, prog_liderazgo, camila_responses, camila_manifesto)
populate_demo_history!(mateo, prog_cambio, mateo_responses, mateo_manifesto)
populate_demo_history!(sofia, prog_productividad, sofia_responses, sofia_manifesto)

puts "Successfully seeded 3 completed participants with full 14-day history."

# ----------------- Additional Edge Cases / Test Data -----------------
puts "--- Seeding Additional Test Cases (Active, Paused, Pending, Stuck, Pending Responses, Unknown Inbounds, Failed Messages) ---"

# Helper for partial participant history (used for active/paused/stuck)
def populate_partial_history!(participant, program, responses, max_day)
  puts "Seeding partial history for #{participant.name} up to Day #{max_day}..."

  # Create Day 0 / Welcome interactions
  welcome_content = "¡Hola #{participant.name}! Bienvenido/a a #{program.name}. Escríbeme: #{program.manifesto.split("\n").last}"

  Conversation.create!(
    participant: participant,
    day_number: 0,
    moment: :welcome,
    role: :assistant,
    body: welcome_content,
    created_at: (max_day + 1).days.ago.beginning_of_day + 10.hours,
    sent_at: (max_day + 1).days.ago.beginning_of_day + 10.hours,
    delivered_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 2.seconds,
    read_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 1.minute
  )

  Conversation.create!(
    participant: participant,
    day_number: 0,
    moment: :welcome,
    role: :user,
    body: participant.initial_pattern || "Quiero mejorar en mi día a día.",
    created_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 5.minutes,
    sent_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 5.minutes,
    delivered_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 5.minutes + 1.second,
    read_at: (max_day + 1).days.ago.beginning_of_day + 10.hours + 5.minutes + 1.second
  )

  # Create Days 1 to max_day
  (1..max_day).each do |day|
    day_content = DayContent.find_by!(program: program, day_number: day)
    day_data = responses[day] || {
      response: "Hoy intenté aplicar lo propuesto. Noto que me cuesta un poco, pero le veo sentido.",
      summary: "Avance del participante observando conductas y buscando focos.",
      pattern: "Práctica inicial"
    }

    base_time = (max_day - day + 1).days.ago

    # 1. morning_wake (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :morning_wake,
      role: :assistant,
      body: day_content.morning_template.gsub("{name}", participant.name),
      created_at: base_time.beginning_of_day + 7.hours + 30.minutes,
      sent_at: base_time.beginning_of_day + 7.hours + 30.minutes,
      delivered_at: base_time.beginning_of_day + 7.hours + 30.minutes + 2.seconds,
      read_at: base_time.beginning_of_day + 7.hours + 35.minutes
    )

    # 2. iareto (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :iareto,
      role: :assistant,
      body: day_content.iareto_text,
      created_at: base_time.beginning_of_day + 8.hours,
      sent_at: base_time.beginning_of_day + 8.hours,
      delivered_at: base_time.beginning_of_day + 8.hours + 2.seconds,
      read_at: base_time.beginning_of_day + 8.hours + 10.minutes
    )

    # 3. checkin_question (assistant)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :checkin_question,
      role: :assistant,
      body: day_content.checkin_questions,
      created_at: base_time.beginning_of_day + 20.hours,
      sent_at: base_time.beginning_of_day + 20.hours,
      delivered_at: base_time.beginning_of_day + 20.hours + 2.seconds,
      read_at: base_time.beginning_of_day + 20.hours + 15.minutes
    )

    # 4. checkin_response (user)
    Conversation.create!(
      participant: participant,
      day_number: day,
      moment: :checkin_response,
      role: :user,
      body: day_data[:response],
      created_at: base_time.beginning_of_day + 20.hours + 20.minutes,
      sent_at: base_time.beginning_of_day + 20.hours + 20.minutes,
      delivered_at: base_time.beginning_of_day + 20.hours + 20.minutes + 1.second,
      read_at: base_time.beginning_of_day + 20.hours + 20.minutes + 1.second
    )

    # 5. DailyReport
    DailyReport.create!(
      participant: participant,
      day_number: day,
      raw_text: day_data[:response],
      ai_summary: day_data[:summary],
      ai_key_pattern: day_data[:pattern],
      reported_at: base_time.beginning_of_day + 20.hours + 21.minutes,
      created_at: base_time.beginning_of_day + 20.hours + 21.minutes,
      updated_at: base_time.beginning_of_day + 20.hours + 21.minutes
    )
  end
end

# 4. Active Participant (Tomás Silva - Day 3 Liderazgo)
tomas = Participant.create!(
  name: "Tomás Silva",
  phone_e164: "+56944444444",
  email: "tomas.silva@lider.cl",
  status: :active,
  current_day: 3,
  timezone: "America/Santiago",
  company: "Líder Group",
  role: "Engineering Manager",
  initial_pattern: "Tiendo a no delegar la revisión técnica final de los pulls requests porque me preocupa que se suban bugs a producción.",
  enrolled_at: 3.days.ago,
  started_at: 3.days.ago,
  energy_map: { "lunes" => [ 3, 4 ], "martes" => [ 2, 4 ], "miercoles" => [ 3, 3 ] }
)
populate_partial_history!(tomas, prog_liderazgo, camila_responses, 2)

# On day 3, Tomas received morning_wake, iareto, checkin_question, but hasn't responded yet
day3_content = DayContent.find_by!(program: prog_liderazgo, day_number: 3)
Conversation.create!(
  participant: tomas,
  day_number: 3,
  moment: :morning_wake,
  role: :assistant,
  body: day3_content.morning_template.gsub("{name}", tomas.name),
  created_at: 4.hours.ago,
  sent_at: 4.hours.ago,
  delivered_at: 4.hours.ago + 2.seconds,
  read_at: 4.hours.ago + 10.minutes
)
Conversation.create!(
  participant: tomas,
  day_number: 3,
  moment: :iareto,
  role: :assistant,
  body: day3_content.iareto_text,
  created_at: 3.hours.ago + 30.minutes,
  sent_at: 3.hours.ago + 30.minutes,
  delivered_at: 3.hours.ago + 30.minutes + 2.seconds,
  read_at: 3.hours.ago + 35.minutes
)
Conversation.create!(
  participant: tomas,
  day_number: 3,
  moment: :checkin_question,
  role: :assistant,
  body: day3_content.checkin_questions,
  created_at: 1.hour.ago,
  sent_at: 1.hour.ago,
  delivered_at: 1.hour.ago + 2.seconds,
  read_at: 1.hour.ago + 5.minutes
)
tomas.update!(pending_checkin_at: 1.hour.ago)


# 5. Active Participant with Pending Responses (Valentina Gómez - Day 5 Cambio)
valentina = Participant.create!(
  name: "Valentina Gómez",
  phone_e164: "+56955555555",
  email: "valentina.gomez@empresa.com",
  status: :active,
  current_day: 5,
  timezone: "America/Santiago",
  company: "Empresa S.A.",
  role: "Analista de Procesos",
  initial_pattern: "Siento resistencia a usar los nuevos flujos digitales en la intranet porque la interfaz es muy confusa y lenta.",
  enrolled_at: 5.days.ago,
  started_at: 5.days.ago,
  response_mode: "approve", # Force approve mode to trigger pending responses
  energy_map: { "lunes" => [ 3, 3 ], "martes" => [ 3, 4 ], "miercoles" => [ 4, 4 ], "jueves" => [ 3, 3 ] }
)
populate_partial_history!(valentina, prog_cambio, mateo_responses, 4)

# On Day 5, Valentina receives checkin_question, responds to it, and the AI generates a reply that is pending approval
day5_content = DayContent.find_by!(program: prog_cambio, day_number: 5)
Conversation.create!(
  participant: valentina,
  day_number: 5,
  moment: :morning_wake,
  role: :assistant,
  body: day5_content.morning_template.gsub("{name}", valentina.name),
  created_at: 8.hours.ago,
  sent_at: 8.hours.ago,
  delivered_at: 8.hours.ago + 2.seconds,
  read_at: 8.hours.ago + 5.minutes
)
Conversation.create!(
  participant: valentina,
  day_number: 5,
  moment: :iareto,
  role: :assistant,
  body: day5_content.iareto_text,
  created_at: 7.hours.ago + 30.minutes,
  sent_at: 7.hours.ago + 30.minutes,
  delivered_at: 7.hours.ago + 30.minutes + 2.seconds,
  read_at: 7.hours.ago + 32.minutes
)
Conversation.create!(
  participant: valentina,
  day_number: 5,
  moment: :checkin_question,
  role: :assistant,
  body: day5_content.checkin_questions,
  created_at: 3.hours.ago,
  sent_at: 3.hours.ago,
  delivered_at: 3.hours.ago + 2.seconds,
  read_at: 3.hours.ago + 1.minute
)
valentina.update!(pending_checkin_at: 3.hours.ago)

user_reply = Conversation.create!(
  participant: valentina,
  day_number: 5,
  moment: :checkin_response,
  role: :user,
  body: "Hoy me costó mucho usar SAP porque no había internet en la bodega de mermas, así que volví a usar la planilla Excel vieja temporalmente.",
  created_at: 2.hours.ago,
  sent_at: 2.hours.ago,
  delivered_at: 2.hours.ago + 1.second,
  read_at: 2.hours.ago + 1.second
)

# Ensure an AdminUser exists for pending responses approvals/rejections
admin_user = AdminUser.first
if admin_user.nil?
  admin_user = AdminUser.create!(
    email: "admin@impulso.com",
    password: "password123",
    password_confirmation: "password123",
    name: "Admin Default"
  )
  puts "Created default admin user for seeds: admin@impulso.com / password123"
end

# 1. PENDING RESPONSE (Pending approval)
PendingResponse.create!(
  participant: valentina,
  conversation: user_reply,
  mode: "approve",
  moment: "checkin_response",
  day_number: 5,
  draft_body: "Valentina, es muy comprensible que recurras al Excel si no hay señal. ¿Cómo crees que podemos reportar rápido esa falta de red para que TI lo resuelva y no vuelvas a quedar con doble registro?",
  original_body: "Valentina, es muy comprensible que recurras al Excel si no hay señal. ¿Cómo crees que podemos reportar rápido esa falta de red para que TI lo resuelva y no vuelvas a quedar con doble registro?",
  delivery_kind: "text",
  status: "pending",
  created_at: 2.hours.ago + 1.minute,
  updated_at: 2.hours.ago + 1.minute
)

# 2. REJECTED RESPONSE (to show rejected history)
PendingResponse.create!(
  participant: valentina,
  mode: "suggest",
  moment: "free_assistant",
  day_number: 3,
  draft_body: "Hola Valentina, es importante que sigas usando SAP siempre. Saludos.",
  original_body: "Hola Valentina, es importante que sigas usando SAP siempre. Saludos.",
  delivery_kind: "text",
  status: "rejected",
  rejection_reason: "Tono demasiado cortante e imperativo, no empático.",
  created_at: 2.days.ago,
  updated_at: 2.days.ago
)

# 3. APPROVED RESPONSE (already acted upon/sent)
convo_approved = Conversation.create!(
  participant: valentina,
  day_number: 4,
  moment: :free_assistant,
  role: :assistant,
  body: "Excelente observación sobre el apoyo mutuo en bodega. Habilitar la ayuda entre operarios reduce la curva de aprendizaje muchísimo.",
  created_at: 1.day.ago,
  sent_at: 1.day.ago,
  delivered_at: 1.day.ago + 2.seconds,
  read_at: 1.day.ago + 10.minutes
)
PendingResponse.create!(
  participant: valentina,
  conversation: convo_approved,
  mode: "approve",
  moment: "free_assistant",
  day_number: 4,
  draft_body: "Excelente observación sobre el apoyo mutuo en bodega. Habilitar la ayuda entre operarios reduce la curva de aprendizaje muchísimo.",
  original_body: "Excelente observación sobre el apoyo mutuo en bodega. Habilitar la ayuda entre operarios reduce la curva de aprendizaje muchísimo.",
  delivery_kind: "text",
  status: "sent",
  approved_by: admin_user,
  acted_at: 1.day.ago + 1.minute,
  created_at: 1.day.ago,
  updated_at: 1.day.ago + 1.minute
)


# 6. Paused Participant (Andrés Castro - Day 8 Productividad)
andres = Participant.create!(
  name: "Andrés Castro",
  phone_e164: "+56966666666",
  email: "andres.castro@consultores.cl",
  status: :paused,
  current_day: 8,
  timezone: "America/Santiago",
  company: "Austral Consultores",
  role: "Consultor Senior",
  initial_pattern: "Siento que me quedo pegado respondiendo correos pequeños en vez de preparar el informe de auditoría.",
  enrolled_at: 8.days.ago,
  started_at: 8.days.ago,
  energy_map: { "lunes" => [ 3, 4 ], "martes" => [ 2, 3 ], "miercoles" => [ 4, 4 ] }
)
populate_partial_history!(andres, prog_productividad, sofia_responses, 7)


# 7. Pending Participant (Elena Ruiz - Day 0 Liderazgo)
elena = Participant.create!(
  name: "Elena Ruiz",
  phone_e164: "+56977777777",
  email: "elena.ruiz@innovacion.cl",
  status: :pending,
  current_day: 0,
  timezone: "America/Santiago",
  company: "Innovación Activa",
  role: "Project Manager",
  enrolled_at: 1.day.ago,
  started_at: nil,
  energy_map: { "lunes" => [ 3, 4 ], "martes" => [ 3, 4 ] }
)
welcome_msg = "¡Hola Elena! Bienvenido/a a Impulso Liderazgo en Acción. Escríbeme: ¿Qué hábito de liderazgo necesitas fortalecer durante estas dos semanas?"
Conversation.create!(
  participant: elena,
  day_number: 0,
  moment: :welcome,
  role: :assistant,
  body: welcome_msg,
  created_at: 1.day.ago + 10.hours,
  sent_at: 1.day.ago + 10.hours,
  delivered_at: 1.day.ago + 10.hours + 2.seconds,
  read_at: 1.day.ago + 10.hours + 1.minute
)


# 8. Stuck Active Participant (Ignacio Pérez - Day 4 Liderazgo, enrolled 6 days ago, inactive for last 3 days)
ignacio = Participant.create!(
  name: "Ignacio Pérez",
  phone_e164: "+56988888888",
  email: "ignacio.perez@holding.cl",
  status: :active,
  current_day: 4,
  timezone: "America/Santiago",
  company: "Holding Industrial",
  role: "Jefe de Operaciones",
  initial_pattern: "Suelo gritar o alzar la voz en reuniones cuando las metas de despacho no se cumplen a tiempo.",
  enrolled_at: 6.days.ago,
  started_at: 6.days.ago,
  created_at: 6.days.ago, # Ensure matches stuck query (created_at < 3.days.ago)
  energy_map: { "lunes" => [ 3, 3 ], "martes" => [ 4, 4 ], "miercoles" => [ 3, 3 ] }
)
# Populate days 1 & 2 (completed)
populate_partial_history!(ignacio, prog_liderazgo, camila_responses, 2)

# On Day 3 (3 days ago) and Day 4 (2 days ago), he received messages but didn't respond
[ 3, 4 ].each do |day|
  day_content = DayContent.find_by!(program: prog_liderazgo, day_number: day)
  base_time = (5 - day).days.ago

  Conversation.create!(
    participant: ignacio,
    day_number: day,
    moment: :morning_wake,
    role: :assistant,
    body: day_content.morning_template.gsub("{name}", ignacio.name),
    created_at: base_time.beginning_of_day + 7.hours + 30.minutes,
    sent_at: base_time.beginning_of_day + 7.hours + 30.minutes,
    delivered_at: base_time.beginning_of_day + 7.hours + 30.minutes + 2.seconds,
    read_at: base_time.beginning_of_day + 7.hours + 35.minutes
  )

  Conversation.create!(
    participant: ignacio,
    day_number: day,
    moment: :iareto,
    role: :assistant,
    body: day_content.iareto_text,
    created_at: base_time.beginning_of_day + 8.hours,
    sent_at: base_time.beginning_of_day + 8.hours,
    delivered_at: base_time.beginning_of_day + 8.hours + 2.seconds,
    read_at: base_time.beginning_of_day + 8.hours + 10.minutes
  )

  Conversation.create!(
    participant: ignacio,
    day_number: day,
    moment: :checkin_question,
    role: :assistant,
    body: day_content.checkin_questions,
    created_at: base_time.beginning_of_day + 20.hours,
    sent_at: base_time.beginning_of_day + 20.hours,
    delivered_at: base_time.beginning_of_day + 20.hours + 2.seconds,
    read_at: base_time.beginning_of_day + 20.hours + 15.minutes
  )
end


# 9. Failed Message / Delivery Errors (For visual statistics)
Conversation.create!(
  participant: tomas,
  day_number: 1,
  moment: :morning_wake,
  role: :assistant,
  body: "Hola Tomás, comencemos el día enfocados en el liderazgo.",
  error_message: "Meta Cloud API Error: Recipient phone number not in WhatsApp Sandbox registry",
  created_at: 2.days.ago,
  updated_at: 2.days.ago
)


# 10. Unknown Inbound Messages
UnknownInbound.create!(
  phone: "+56999999999",
  wamid: "wamid.seed_unknown_1",
  message_type: "text",
  body_preview: "Hola, me gustaría saber si el programa de liderazgo sirve para empresas de retail.",
  received_at: 1.hour.ago,
  created_at: 1.hour.ago
)

UnknownInbound.create!(
  phone: "+56999998888",
  wamid: "wamid.seed_unknown_2",
  message_type: "text",
  body_preview: "Quiero inscribirme",
  received_at: 1.day.ago,
  created_at: 1.day.ago
)

puts "Successfully seeded additional test cases (Active, Paused, Pending, Stuck, Pending Responses, Unknown Inbounds, Failed Messages)."
