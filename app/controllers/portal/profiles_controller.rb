module Portal
  # Datos del perfil del participante. Editable: nombre y zona horaria.
  # Email y teléfono son de solo lectura (el email ancla el magic-link y el
  # teléfono es la identidad de WhatsApp).
  class ProfilesController < BaseController
    # Curated IANA zones offered in the picker; the participant's current zone is
    # always included so it can't be silently dropped.
    COMMON_ZONES = [
      "America/Santiago", "America/Mexico_City", "America/Bogota", "America/Lima",
      "America/Argentina/Buenos_Aires", "America/Sao_Paulo", "America/New_York",
      "Europe/Madrid"
    ].freeze

    def show
      @participant = current_participant
      @zones = (COMMON_ZONES + [ @participant.timezone ]).compact.uniq.sort
    end

    def update
      @participant = current_participant
      attrs = profile_params

      if attrs[:timezone].present? && ActiveSupport::TimeZone[attrs[:timezone]].nil?
        @zones = (COMMON_ZONES + [ @participant.timezone ]).compact.uniq.sort
        flash.now[:alert] = "Zona horaria inválida."
        return render :show, status: :unprocessable_entity
      end

      if @participant.update(attrs)
        redirect_to portal_profile_path, notice: "Guardamos tus cambios."
      else
        @zones = (COMMON_ZONES + [ @participant.timezone ]).compact.uniq.sort
        flash.now[:alert] = @participant.errors.full_messages.to_sentence
        render :show, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:participant).permit(:name, :timezone)
    end
  end
end
