module Admin
  class ResourcesController < BaseController
    before_action :set_resource, only: %i[show edit update destroy approve reject verify_again]

    def index
      @resources = Resource.kept.includes(:program).ordered
      @resources = @resources.where(status: params[:status]) if params[:status].present?
      @resources = @resources.where(kind: params[:kind]) if params[:kind].present?
      @resources = @resources.where(program_id: params[:program_id]) if params[:program_id].present?
      @resources = @resources.where("topics @> ?", [ params[:topic].to_s ].to_json) if params[:topic].present?
      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        @resources = @resources.where("LOWER(resources.title) LIKE :q OR LOWER(resources.url) LIKE :q OR LOWER(resources.description) LIKE :q", q: q)
      end

      @total_count = Resource.kept.count
      @verified_count = Resource.kept.verified.count
      @dead_count = Resource.kept.dead.count
      @programs = Program.order(:name)
    end

    def show
      @deliveries = @resource.resource_deliveries.includes(:participant, :conversation).order(created_at: :desc).limit(50)
    end

    def new
      @resource = Resource.new(status: :pending, source: :manual, kind: :article)
    end

    def create
      @resource = Resource.new(resource_params)
      @resource.source = :manual
      @resource.status = :pending
      @resource.topics = topics_from_params

      if @resource.save
        Resources::Verifier.new(resource: @resource).call
        redirect_to admin_resource_path(@resource), notice: "Recurso creado y verificado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = resource_params.merge(topics: topics_from_params)
      if @resource.update(attrs)
        redirect_to admin_resource_path(@resource), notice: "Recurso actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def approve
      @resource.update!(status: :approved)
      redirect_to admin_resources_path(status: "verified"), notice: "Recurso aprobado."
    end

    def reject
      @resource.update!(status: :rejected)
      redirect_to admin_resources_path(status: "verified"), notice: "Recurso rechazado."
    end

    def verify_again
      Resources::Verifier.new(resource: @resource).call
      redirect_to admin_resource_path(@resource), notice: "Recurso verificado nuevamente."
    end

    def destroy
      @resource.discard!
      redirect_to admin_resources_path, notice: "Recurso archivado."
    end

    private

    def set_resource
      @resource = Resource.kept.find(params[:id])
    end

    def resource_params
      params.require(:resource).permit(:title, :url, :kind, :status, :description, :program_id)
    end

    def topics_from_params
      params.dig(:resource, :topics_text).to_s.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
