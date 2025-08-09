module LeaderboardDateRange
  module_function

  def calculate(date, period)
    case period
    when :weekly
      (date.beginning_of_day...(date + 7.days).beginning_of_day)
    when :last_7_days
      ((date - 6.days).beginning_of_day...date.end_of_day)
    else
      date.all_day
    end
  end

  def normalize_date(date, period)
    date = Date.current if date.blank?
    date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    date = date.beginning_of_week if period == :weekly
    date
  end
end
