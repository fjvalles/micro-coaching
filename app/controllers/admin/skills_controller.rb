module Admin
  class SkillsController < BaseController
    def index
      @skills = Skill.with_detection_counts.ordered
    end

    def show
      @skill = Skill.find(params[:id])
      @recent_detections = @skill.skill_detections.recent.includes(:participant).limit(20)
    end
  end
end
