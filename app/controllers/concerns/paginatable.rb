module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  def paginate(scope, per_page: DEFAULT_PER_PAGE)
    per_page = params[:per_page].to_i if params[:per_page].present?
    per_page = [ per_page.to_i, MAX_PER_PAGE ].min
    per_page = DEFAULT_PER_PAGE if per_page <= 0

    page = params[:page].to_i
    page = 1 if page < 1

    total_count = scope.except(:order, :select).count
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    page = total_pages if page > total_pages

    @pagination = {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
    @page = page
    @per_page = per_page
    @total_count = total_count
    @total_pages = total_pages

    scope.limit(per_page).offset((page - 1) * per_page)
  end
end
