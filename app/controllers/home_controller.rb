class HomeController < ApplicationController
  layout "landing"
  def index
    @program = Program.default
  end

  def preview_challenge
    goal = params[:goal].to_s.strip
    if goal.blank?
      render json: { error: "Por favor escribe un objetivo o hábito que quieras cambiar." }, status: :unprocessable_entity
      return
    end

    begin
      client = Openai::Client.new
      system_prompt = <<~PROMPT
        Eres el coach inteligente de "Impulso by Comtraining", un programa de micro-coaching conductual de 14 días enviado a través de WhatsApp.
        El usuario está en la página web conociendo el programa y quiere una demostración de cómo sería su primer día personalizado.
        Genera una simulación realista de un mensaje de WhatsApp que le enviarías para empezar su Día 1.

        Reglas estrictas para el mensaje:
        1. Debe ser en español (amigable, motivador, directo y profesional).
        2. Personalízalo asumiendo que su meta es: "#{goal}".
        3. Mantén el formato de WhatsApp (puedes usar *negrita* para enfatizar).
        4. Debe incluir:
           - Un saludo enérgico e introductorio.
           - Un desafío/reto concreto para el Día 1 relacionado con su meta (debe ser muy simple de cumplir, un "micro-paso").
           - Una pregunta corta al final para invitar a la acción.
        5. Máximo 4 frases. Sé conciso y no uses marcadores de posición como "[Nombre]". Escribe como si te dirigieras al usuario directamente.
      PROMPT

      result = client.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "Meta del usuario: #{goal}. Genera el mensaje." }
        ],
        max_tokens: 300,
        temperature: 0.75,
        task: :preview_challenge
      )

      render json: { challenge: result.content }
    rescue => e
      Rails.logger.error("OpenAI Preview Error: #{e.message}")
      render json: { error: "Hubo un error generando tu reto. Por favor intenta de nuevo." }, status: :internal_server_error
    end
  end

  def enroll
    name = params[:name].to_s.strip
    phone = params[:phone].to_s.strip
    company = params[:company].to_s.strip
    role = params[:role].to_s.strip
    email = params[:email].to_s.strip
    timezone = params[:timezone].presence || ENV.fetch("DEFAULT_TIMEZONE", "America/Santiago")

    # Basic validations
    if name.blank? || phone.blank? || email.blank?
      flash[:alert] = "El nombre, el teléfono y el correo electrónico son obligatorios."
      redirect_to root_path and return
    end

    # E.164 conversion if missing country code prefix
    phone_clean = phone.gsub(/\s+|-|\(|\)/, "")
    unless phone_clean.start_with?("+")
      phone_clean = "+" + phone_clean
    end

    # Double check formatting against Participant model regex
    unless phone_clean =~ /\A\+\d{8,15}\z/
      flash[:alert] = "El teléfono debe estar en formato internacional con código de país (ej. +56912345678)."
      redirect_to root_path and return
    end

    # Check if participant already exists and is kept
    existing = Participant.kept.find_by(phone_e164: phone_clean)
    if existing
      flash[:alert] = "Este número de teléfono ya está registrado en el programa."
      redirect_to root_path and return
    end

    begin
      participant = Participants::Enroller.new(
        name: name,
        phone_e164: phone_clean,
        timezone: timezone,
        company: company,
        role: role,
        email: email
      ).call

      # Payment-gated individuals pay first; activation + welcome happen on the
      # Webpay commit. Everyone else (company-covered, or payments off) is already
      # active and gets the WhatsApp kick-off page below.
      if participant.awaiting_payment?
        redirect_to pagos_path(participant_id: participant.id) and return
      end

      # Get wa.me link with custom text to facilitate immediate interaction
      # Use either Meta configuration or fallback to a dummy/real number if configured.
      # Meta Business Phone is generally not suitable for direct user messaging wa.me links,
      # but let's fetch it from config or use a generic WhatsApp link if unavailable.
      phone_id = ENV["META_PHONE_NUMBER_ID"].presence || "56937667468"
      welcome_text = "Hola. Acabo de inscribirme en Impulso by Comtraining y quiero comenzar."
      @wa_url = "https://wa.me/#{phone_id}?text=#{CGI.escape(welcome_text)}"
      @participant = participant

      render :success
    rescue => e
      Rails.logger.error("Enrollment Error: #{e.message}")
      flash[:alert] = "Hubo un error al inscribirte: #{e.message}"
      redirect_to root_path
    end
  end

  def privacidad
    @privacy_policy = Setting.fetch("privacy_policy")
  end
end
