namespace :data do
  desc "Corrige tildes y eñes faltantes comunes en los programas y contenidos de día"
  task fix_spelling: :environment do
    puts "Iniciando corrección ortográfica de textos generados..."

    # Diccionario de reemplazos seguros
    replacements = {
      "\\bano\\b" => "año",
      "\\banos\\b" => "años",
      "\\bdespues\\b" => "después",
      "\\bdia\\b" => "día",
      "\\bdias\\b" => "días",
      "\\bpequeno\\b" => "pequeño",
      "\\bpequena\\b" => "pequeña",
      "\\bpequenos\\b" => "pequeños",
      "\\bpequenas\\b" => "pequeñas",
      "\\bhabito\\b" => "hábito",
      "\\bhabitos\\b" => "hábitos",
      "\\btambien\\b" => "también",
      "\\bmas\\b" => "más", # 'mas' como conjunción es rarísimo en este contexto
      "\\baccion\\b" => "acción",
      "\\bacciones\\b" => "acciones",
      "\\breflexion\\b" => "reflexión",
      "\\benergia\\b" => "energía",
      "\\bproposito\\b" => "propósito",
      "\\bexito\\b" => "éxito",
      "\\bfacil\\b" => "fácil",
      "\\bdificil\\b" => "difícil",
      "\\brapido\\b" => "rápido",
      "\\bunicamente\\b" => "únicamente",
      "\\bproximo\\b" => "próximo",
      "\\bproxima\\b" => "próxima",
      "\\bsegun\\b" => "según",
      "\\bestan\\b" => "están",
      "\\bestas\\b" => "estás"
    }

    def apply_replacements(text, replacements)
      return text if text.blank?

      new_text = text.dup
      replacements.each do |pattern, replacement|
        # Reemplaza respetando si la primera letra era mayúscula (ej: Dia -> Día)
        new_text.gsub!(/#{pattern}/i) do |match|
          if match[0] == match[0].upcase
            replacement.capitalize
          else
            replacement
          end
        end
      end
      new_text
    end

    # 1. Corregir DayContents
    changed_day_contents = 0
    DayContent.find_each do |day|
      changes = false

      %w[title morning_template iareto_text checkin_questions ai_system_prompt].each do |field|
        original = day.public_send(field)
        corrected = apply_replacements(original, replacements)

        if original != corrected
          day.public_send("\#{field}=", corrected)
          changes = true
        end
      end

      if changes
        day.save!(touch: false) # touch: false para no interferir con cachés si no es necesario, o true si sí
        changed_day_contents += 1
      end
    end

    # 2. Corregir Programs (manifestos, names)
    changed_programs = 0
    Program.find_each do |program|
      changes = false

      %w[name manifesto].each do |field|
        original = program.public_send(field)
        corrected = apply_replacements(original, replacements)

        if original != corrected
          program.public_send("\#{field}=", corrected)
          changes = true
        end
      end

      if changes
        program.save!(touch: false)
        changed_programs += 1
      end
    end

    puts "Corrección completada:"
    puts "- \#{changed_day_contents} Días (DayContent) corregidos."
    puts "- \#{changed_programs} Programas corregidos."
  end
end
