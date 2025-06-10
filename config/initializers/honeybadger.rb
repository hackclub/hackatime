# Honeybadger programmatic error filtering to prevent rate limit exhaustion
Honeybadger.configure do |config|
  @error_counts = Hash.new { |hash, key| hash[key] = { hourly: [], daily: [] } }

  # Rate limiting configuration
  MAX_ERRORS_PER_HOUR = 10
  MAX_ERRORS_PER_DAY = 50

  config.before_notify do |notice|
    if notice.error_class == "Norairrecord::Error" && notice.error_message&.include?("HTTP 429")
      return false
    end

    error_index = generate_error_index notice

    should_ignore = rate_limit_exceeded? error_index

    record_error_occurrence error_index unless should_ignore

    !should_ignore
  end

  private

  def generate_error_index(notice)
    if notice.backtrace&.any?
      first_stack_line = notice.backtrace.first
      "#{notice.error_class}:#{first_stack_line}"
    else
      controller = notice.context[:controller]
      action = notice.context[:action]
      "#{notice.error_class}:#{controller}:#{action}"
    end
  end

  def rate_limit_exceeded?(error_index)
    now = Time.current
    one_hour_ago = now - 1.hour
    one_day_ago = now - 1.day

    @error_counts[error_index][:hourly].reject! { |timestamp| timestamp < one_hour_ago }
    @error_counts[error_index][:daily].reject! { |timestamp| timestamp < one_day_ago }

    hourly_count = @error_counts[error_index][:hourly].size
    daily_count = @error_counts[error_index][:daily].size

    hourly_count >= MAX_ERRORS_PER_HOUR || daily_count >= MAX_ERRORS_PER_DAY
  end

  def record_error_occurrence(error_index)
    now = Time.current
    @error_counts[error_index][:hourly] << now
    @error_counts[error_index][:daily] << now
  end
end
