module Admin
  class ProgramsController < BaseController
    before_action :set_program, only: [ :show, :edit, :update, :destroy ]

    def index
      @programs = Program.all.order(:name)
    end

    def show
      @day_contents = @program.day_contents.order(:day_number)
      @participants = @program.participants.kept.order(created_at: :desc)
    end

    def new
      @program = Program.new(total_days: 14)
    end

    def edit
    end

    def create
      @program = Program.new(program_params)
      if @program.save
        redirect_to admin_program_path(@program), notice: "Programa creado exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @program.update(program_params)
        redirect_to admin_program_path(@program), notice: "Programa actualizado exitosamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @program.destroy
      redirect_to admin_programs_path, notice: "Programa eliminado."
    end

    private

    def set_program
      @program = Program.find(params[:id])
    end

    def program_params
      params.require(:program).permit(:name, :slug, :description, :manifesto, :total_days, :active, :response_mode)
    end
  end
end
