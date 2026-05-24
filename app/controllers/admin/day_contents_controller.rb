module Admin
  class DayContentsController < BaseController
    include Paginatable

    before_action :set_program_context
    before_action :set_day_content, only: [ :show, :edit, :update, :destroy ]

    def index
      @programs = Program.ordered
      @day_number_options = DayContent.distinct.order(:day_number).pluck(:day_number)

      query = DayContentsQuery.from_params(params, program_context: @program_context)
      @filters = query.to_h
      @day_contents = paginate(query.resolve)
    end

    def show
    end

    def new
      @day_content = DayContent.new(program_id: @program_context&.id || params[:program_id], active: true)
      @programs = Program.ordered
    end

    def edit
      @programs = Program.ordered
    end

    def create
      @day_content = DayContent.new(day_content_params)
      @programs = Program.ordered
      if @day_content.save
        redirect_to day_content_redirect_path(@day_content), notice: "Contenido del día creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @programs = Program.ordered
      if @day_content.update(day_content_params)
        redirect_to day_content_redirect_path(@day_content), notice: "Contenido del día actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      program = @day_content.program
      @day_content.destroy
      if should_return_to_program?(program.id)
        redirect_to admin_program_day_contents_path(program), notice: "Contenido del día eliminado."
      else
        redirect_to admin_day_contents_path, notice: "Contenido del día eliminado."
      end
    end

    private

    def set_program_context
      program_id = params[:program_id].presence || params[:return_to_program_id].presence
      @program_context = Program.find_by(id: program_id) if program_id.present?
    end

    def set_day_content
      @day_content = DayContent.find(params[:id])
      @program_context ||= @day_content.program if should_return_to_program?(@day_content.program_id)
    end

    def day_content_params
      params.require(:day_content).permit(
        :program_id, :day_number, :phase, :title,
        :template_name_whatsapp, :morning_template,
        :iareto_text, :checkin_questions, :ai_system_prompt, :active
      )
    end

    def should_return_to_program?(program_id = nil)
      program_id.present? && params[:return_to_program_id].presence == program_id.to_s
    end

    def day_content_redirect_path(day_content)
      if should_return_to_program?(day_content.program_id) || params[:program_id].present?
        admin_day_content_path(day_content, return_to_program_id: day_content.program_id)
      else
        admin_day_content_path(day_content)
      end
    end
  end
end
