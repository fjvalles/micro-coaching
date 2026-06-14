module Portal
  # Links / fuentes que el participante recibió por WhatsApp, con acceso fácil.
  # Deduplicado por recurso (queda la entrega más reciente), solo recursos vigentes.
  class ResourcesController < BaseController
    def index
      @resources = current_participant.shared_resources
    end
  end
end
