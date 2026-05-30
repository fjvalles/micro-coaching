module Admin
  class CompaniesController < BaseController
    before_action :set_company, only: %i[show edit update discard undiscard]

    def index
      @companies = Company.kept.ordered
      @discarded_companies = Company.discarded.ordered
    end

    def show
      @participants = @company.participants.kept.order(created_at: :desc)
      @programs = @company.programs.order(:name)
    end

    def new
      @company = Company.new(active: true, covers_membership: true)
    end

    def edit
    end

    def create
      @company = Company.new(company_params)
      if @company.save
        redirect_to admin_company_path(@company), notice: "Empresa creada exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @company.update(company_params)
        redirect_to admin_company_path(@company), notice: "Empresa actualizada exitosamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def discard
      @company.discard
      redirect_to admin_companies_path, notice: "Empresa archivada."
    end

    def undiscard
      @company.undiscard
      redirect_to admin_companies_path, notice: "Empresa restaurada."
    end

    private

    def set_company
      @company = Company.find(params[:id])
    end

    def company_params
      params.require(:company).permit(:name, :slug, :coach_name, :contact_email, :active, :covers_membership, :notes)
    end
  end
end
