module Admin
  class AuditLogsController < BaseController
    before_action :require_superadmin
    TRACKED_TYPES = %w[Participant Program DayContent].freeze

    def index
      scope = PaperTrail::Version.where(item_type: TRACKED_TYPES)

      # Text Search (on whodunnit, object_changes, object, or item_type)
      if params[:q].present?
        scope = scope.where(
          "whodunnit ILIKE :q OR object_changes ILIKE :q OR object ILIKE :q OR item_type ILIKE :q",
          q: "%#{params[:q]}%"
        )
      end

      if params[:item_type].present? && TRACKED_TYPES.include?(params[:item_type])
        scope = scope.where(item_type: params[:item_type])
      end

      if params[:source].present? && %w[admin ai].include?(params[:source])
        scope = scope.where(source: params[:source])
      end

      if params[:event].present? && %w[create update destroy].include?(params[:event])
        scope = scope.where(event: params[:event])
      end

      # Simple pagination
      @page = (params[:page] || 1).to_i
      @per_page = 25
      @total_count = scope.count
      @total_pages = (@total_count.to_f / @per_page).ceil

      @versions = scope.includes(:item)
                        .order(created_at: :desc)
                        .limit(@per_page)
                        .offset((@page - 1) * @per_page)
    end
  end
end
