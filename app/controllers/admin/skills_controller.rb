module Admin
  class SkillsController < BaseController
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
      @skill = Skill.find(params[:id])
      @recent_detections = @skill.skill_detections.recent.includes(:participant).limit(20)
    end
  end
end
