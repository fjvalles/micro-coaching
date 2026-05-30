module PeriodFilterable
  extend ActiveSupport::Concern

  PERIOD_LABELS = {
    "this_month"   => "Este mes",
    "last_month"   => "Mes anterior",
    "last_3months" => "Últimos 3 meses",
    "last_6months" => "Últimos 6 meses",
    "this_year"    => "Este año",
    "all_time"     => "Todo el tiempo"
  }.freeze

  private

  def period_range(period)
    now = Time.current
    case period
    when "this_month"   then now.beginning_of_month..now.end_of_month
    when "last_month"   then (now - 1.month).beginning_of_month..(now - 1.month).end_of_month
    when "last_3months" then 3.months.ago.beginning_of_day..now.end_of_day
    when "last_6months" then 6.months.ago.beginning_of_day..now.end_of_day
    when "this_year"    then now.beginning_of_year..now.end_of_year
    else                     Time.at(0)..now.end_of_day
    end
  end

  def period_label(period)
    PERIOD_LABELS[period] || period
  end
end
