module Admin
  class SkillsController < BaseController
    def index
      @skills = Skill.with_detection_counts.ordered
      @skills_count = Skill.count
      @detections_total = SkillDetection.count
      @participants_tagged = SkillDetection.distinct.count(:participant_id)
    end

    def show
      @skill = Skill.find(params[:id])
      @recent_detections = @skill.skill_detections.recent.includes(:participant).limit(20)
    end
  end
end
