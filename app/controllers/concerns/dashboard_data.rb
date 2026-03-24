module DashboardData
  extend ActiveSupport::Concern

  private

  def filterable_dashboard_data
    filters = %i[project language operating_system editor category]
    interval = params[:interval]
    key = [
      "dashboard-filterable-data",
      current_user.id,
      dashboard_cache_version,
      filters.index_with { |f| params[f].to_s },
      interval.to_s,
      params[:from].to_s,
      params[:to].to_s
    ]
    hb = current_user.heartbeats
    h = ApplicationController.helpers

    Rails.cache.fetch(key, expires_in: 5.minutes) do
      archived = current_user.project_repo_mappings.archived.pluck(:project_name)
      raw_filter_options = cached_dashboard_filter_options
      result = {}

      Time.use_zone(current_user.timezone) do
        filters.each do |f|
          options = raw_filter_options.fetch(f, [])
          options = options.reject { |n| archived.include?(n) } if f == :project
          result[f] = options.map { |k|
            if f == :language then k.categorize_language
            elsif f == :editor then h.display_editor_name(k)
            elsif f == :operating_system then h.display_os_name(k)
            else k
            end
          }.uniq

          next unless params[f].present?
          arr = params[f].split(",")
          hb = if %i[operating_system editor].include?(f)
            hb.where(f => arr.flat_map { |v| [ v.downcase, v.capitalize ] }.uniq)
          elsif f == :language
            raw = raw_filter_options.fetch(:language, []).select { |l| arr.include?(l.categorize_language) }
            raw.any? ? hb.where(f => raw) : hb
          else
            hb.where(f => arr)
          end
          result["singular_#{f}"] = arr.length == 1
        end

        hb = hb.filter_by_time_range(interval, params[:from], params[:to])
        result[:total_time] = hb.duration_seconds
        result[:total_heartbeats] = hb.count

        # Compute per-filter grouped stats in one pass each, then derive top_X and X_stats from the same data
        filter_stats = {}
        filters.each do |f|
          raw_stats = hb.group(f).duration_seconds
          raw_stats = raw_stats.reject { |n, _| archived.include?(n) } if f == :project
          filter_stats[f] = raw_stats
          result["top_#{f}"] = raw_stats.max_by { |_, v| v }&.first
        end

        result["top_editor"] &&= h.display_editor_name(result["top_editor"])
        result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
        result["top_language"] &&= h.display_language_name(result["top_language"])

        unless result["singular_project"]
          result[:project_durations] = filter_stats[:project]
            .sort_by { |_, d| -d }.first(10).to_h
        end

        %i[language editor operating_system category].each do |f|
          next if result["singular_#{f}"]
          stats = filter_stats[f].each_with_object({}) do |(raw, dur), agg|
            k = raw.to_s.presence || "Unknown"
            k = f == :language ? (k == "Unknown" ? k : k.categorize_language) : (%i[editor operating_system].include?(f) ? k.downcase : k)
            agg[k] = (agg[k] || 0) + dur
          end
          result["#{f}_stats"] = stats.sort_by { |_, d| -d }.first(10).map { |k, v|
            label = case f
            when :editor then h.display_editor_name(k)
            when :operating_system then h.display_os_name(k)
            when :language then h.display_language_name(k)
            else k
            end
            [ label, v ]
          }.to_h
        end

        if result["language_stats"].present?
          result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys)
        end

        # Batch all 12 weekly queries into a single ClickHouse query
        week_start = 11.weeks.ago.beginning_of_week
        week_end = Time.current.end_of_week
        weekly_hb = hb.where(time: week_start.to_f..week_end.to_f)

        timeout = Heartbeat.heartbeat_timeout_duration.to_i
        tz = current_user.timezone
        weekly_sql = weekly_hb
          .select("toStartOfWeek(toDateTime(toUInt32(time), '#{tz}'), 1) as week_start, `project` as grouped_time, least(greatest(time - lagInFrame(time, 1, time) OVER (PARTITION BY `project`, toStartOfWeek(toDateTime(toUInt32(time), '#{tz}'), 1) ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 0), #{timeout}) as diff")
          .where.not(time: nil)
          .with_valid_timestamps
          .to_sql

        weekly_rows = Heartbeat.connection.select_all(
          "SELECT toString(week_start) as week_start, grouped_time, toInt64(coalesce(sum(diff), 0)) as duration FROM (#{weekly_sql}) GROUP BY week_start, grouped_time"
        )

        weekly_hash = {}
        weekly_rows.each do |row|
          week_key = row["week_start"].to_date.iso8601
          project = row["grouped_time"]
          next if archived.include?(project)
          weekly_hash[week_key] ||= {}
          weekly_hash[week_key][project] = row["duration"].to_i
        end

        # Ensure all 12 weeks are present (even if empty)
        result[:weekly_project_stats] = (0..11).to_h do |w|
          ws = w.weeks.ago.beginning_of_week.to_date.iso8601
          [ ws, weekly_hash[ws] || {} ]
        end
      end
      result[:selected_interval] = interval.to_s
      result[:selected_from] = params[:from].to_s
      result[:selected_to] = params[:to].to_s
      filters.each { |f| result["selected_#{f}"] = params[f]&.split(",") || [] }

      result
    end
  end

  def activity_graph_data
    tz = current_user.timezone
    key = [ "user-daily-durations", current_user.id, heartbeat_cache_version, tz ]
    durations = Rails.cache.fetch(key, expires_in: 1.minute) do
      Time.use_zone(tz) { current_user.heartbeats.daily_durations(user_timezone: tz).to_h }
    end

    {
      start_date: 365.days.ago.to_date.iso8601,
      end_date: Time.current.to_date.iso8601,
      duration_by_date: durations.transform_keys { |d| d.to_date.iso8601 }.transform_values(&:to_i),
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[tz].to_s,
      timezone_settings_path: "/my/settings#user_timezone"
    }
  end

  def today_stats_data
    Rails.cache.fetch([ "dashboard-today-stats", current_user.id, dashboard_cache_version, current_user.timezone ], expires_in: 5.minutes) do
      h = ApplicationController.helpers
      Time.use_zone(current_user.timezone) do
        rows = current_user.heartbeats.today
          .select(:language, :editor,
                  "COUNT(*) OVER (PARTITION BY language) as language_count",
                  "COUNT(*) OVER (PARTITION BY editor) as editor_count")
          .distinct.to_a

        lang_counts = rows
          .map { |r| [ r.language&.categorize_language, r.language_count ] }
          .reject { |l, _| l.blank? }
          .group_by(&:first).transform_values { |p| p.sum(&:last) }
          .sort_by { |_, c| -c }

        ed_counts = rows
          .map { |r| [ r.editor, r.editor_count ] }
          .reject { |e, _| e.blank? }.uniq
          .sort_by { |_, c| -c }

        todays_languages = lang_counts.map { |l, _| h.display_language_name(l) }
        todays_editors = ed_counts.map { |e, _| h.display_editor_name(e) }
        todays_duration = current_user.heartbeats.today.duration_seconds
        show_logged_time_sentence = todays_duration > 1.minute && (todays_languages.any? || todays_editors.any?)

        {
          show_logged_time_sentence: show_logged_time_sentence,
          todays_duration_display: h.short_time_detailed(todays_duration.to_i),
          todays_languages: todays_languages,
          todays_editors: todays_editors
        }
      end
    end
  end

  def cached_dashboard_filter_options
    Rails.cache.fetch([ "dashboard-filter-options", current_user.id, heartbeat_cache_version ], expires_in: 15.minutes) do
      conn = Heartbeat.connection
      user_id = conn.quote(current_user.id)
      filters = %i[project language operating_system editor category]
      sql = filters.map { |f| "groupUniqArray(#{f}) AS #{f}_values" }.join(", ")
      row = conn.select_one("SELECT #{sql} FROM heartbeats WHERE user_id = #{user_id}")
      filters.index_with { |f| Array(row["#{f}_values"]).reject(&:blank?) }
    end
  end

  def dashboard_cache_version
    @dashboard_cache_version ||= begin
      latest_mapping = current_user.project_repo_mappings.maximum(:updated_at)&.to_i || 0
      [ heartbeat_cache_version, latest_mapping ]
    end
  end

  def heartbeat_cache_version
    @heartbeat_cache_version ||= HeartbeatCacheInvalidator.version_for(current_user)
  end
end
