module Portal
  # Links / fuentes que el participante recibió por WhatsApp, con acceso fácil.
  # Deduplicado por recurso (queda la entrega más reciente), solo recursos vigentes.
  class ResourcesController < BaseController
    def index
      deliveries = current_participant.resource_deliveries
                                      .includes(:resource)
                                      .order(created_at: :desc)

      @resources = deliveries
                   .select { |d| d.resource&.kept? }
                   .uniq { |d| d.resource_id }
    end
  end
end
