module Participants
  # Ordered intake questionnaire used to build a personalized program over WhatsApp.
  # Each entry: key (stored in intake_state["answers"]) + text (sent to the participant).
  # Order is the source of truth for the state machine step index — appending is safe,
  # reordering/removing mid-flight is not (in-flight participants track a numeric step).
  module IntakeQuestions
    ALL = [
      { key: "goal",       text: "Para armar tu programa: en una frase, ¿qué cambio de hábito o conducta quieres lograr en estas semanas?" },
      { key: "pattern",    text: "¿Cuál es el patrón automático o costumbre actual que te gustaría interrumpir?" },
      { key: "obstacle",   text: "¿Qué es lo que más se te interpone hoy para lograrlo?" },
      { key: "time",       text: "¿Cuánto tiempo al día puedes dedicarle, más o menos?" },
      { key: "identity",   text: "¿En quién te quieres convertir? Descríbete como te gustaría ser al terminar." },
      { key: "motivation", text: "¿Por qué ahora? ¿Qué hace que este sea el momento?" },
      { key: "duration",   text: "Por último, ¿cuántos días quieres que dure tu programa? (por ejemplo 7, 14 o 21)" }
    ].freeze

    def self.count
      ALL.size
    end

    # The question for a given zero-based step, or nil when the questionnaire is done.
    def self.at(step)
      ALL[step]
    end
  end
end
