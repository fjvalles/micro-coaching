module Admin
  class SkillsController < BaseController
    before_action :set_skill, only: [ :show, :edit, :update, :destroy ]

    def index
      @skills = Skill.with_detection_counts.ordered
      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        @skills = @skills.where("LOWER(skills.name) LIKE :q OR LOWER(skills.slug) LIKE :q OR LOWER(skills.definition) LIKE :q", q: q)
      end
      @skills_count = Skill.count
      @detections_total = SkillDetection.count
      @participants_tagged = SkillDetection.distinct.count(:participant_id)
    end

    def show
      @recent_detections = @skill.skill_detections.recent.includes(:participant).limit(20)
    end

    def new
      @skill = Skill.new
    end

    def create
      @skill = Skill.new(skill_params)
      if @skill.save
        redirect_to admin_skill_path(@skill), notice: "Habilidad creada exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @skill.update(skill_params)
        redirect_to admin_skill_path(@skill), notice: "Habilidad actualizada exitosamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @skill.destroy
      redirect_to admin_skills_path, notice: "Habilidad eliminada exitosamente."
    end

    private

    def set_skill
      @skill = Skill.find(params[:id])
    end

    def skill_params
      raw_params = params.require(:skill).permit(
        :name, :slug, :position, :definition, :importance, :trap, :one_liner,
        :signals, :practices, :gestures, :exercises, :reflection_questions
      )
      
      Skill::LIST_FIELDS.each do |field|
        if raw_params[field].is_a?(String)
          raw_params[field] = raw_params[field].split("\n").map(&:strip).reject(&:blank?)
        end
      end
      
      raw_params
    end
  end
end
