module Admin
  class AuditLogsController < BaseController
    TRACKED_TYPES = %w[Participant Program DayContent].freeze

    def index
      scope = PaperTrail::Version.where(item_type: TRACKED_TYPES)

      if params[:item_type].present? && TRACKED_TYPES.include?(params[:item_type])
        scope = scope.where(item_type: params[:item_type])
      end

      if params[:source].present? && %w[admin ai].include?(params[:source])
        scope = scope.where(source: params[:source])
      end

      if params[:event].present? && %w[create update destroy].include?(params[:event])
        scope = scope.where(event: params[:event])
      end

      @versions = scope.order(created_at: :desc).limit(200)
    end
  end
end
