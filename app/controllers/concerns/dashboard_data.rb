module DashboardData
  extend ActiveSupport::Concern

  private

  def filterable_dashboard_data
    filters = %i[project language operating_system editor category]
    interval = params[:interval]
    key = [ current_user ] + filters.map { |f| params[f] } + [ interval.to_s, params[:from], params[:to] ]
    hb = current_user.heartbeats
    h = ApplicationController.helpers

    Rails.cache.fetch(key, expires_in: 5.minutes) do
      archived = current_user.project_repo_mappings.archived.pluck(:project_name)
      result = {}

      Time.use_zone(current_user.timezone) do
        filters.each do |f|
          options = current_user.heartbeats.distinct.pluck(f).compact_blank
          options = options.reject { |n| archived.include?(n) } if f == :project
          result[f] = options.map { |k|
            f == :language ? k.categorize_language : (%i[operating_system editor].include?(f) ? k.capitalize : k)
          }.uniq

          next unless params[f].present?
          arr = params[f].split(",")
          hb = if %i[operating_system editor].include?(f)
            hb.where(f => arr.flat_map { |v| [ v.downcase, v.capitalize ] }.uniq)
          elsif f == :language
            raw = current_user.heartbeats.distinct.pluck(f).compact_blank.select { |l| arr.include?(l.categorize_language) }
            raw.any? ? hb.where(f => raw) : hb
          else
            hb.where(f => arr)
          end
          result["singular_#{f}"] = arr.length == 1
        end

        hb = hb.filter_by_time_range(interval, params[:from], params[:to])
        result[:total_time] = hb.duration_seconds
        result[:total_heartbeats] = hb.count

        filters.each do |f|
          stats = hb.group(f).duration_seconds
          stats = stats.reject { |n, _| archived.include?(n) } if f == :project
          result["top_#{f}"] = stats.max_by { |_, v| v }&.first
        end

        result["top_editor"] &&= h.display_editor_name(result["top_editor"])
        result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
        result["top_language"] &&= h.display_language_name(result["top_language"])

        unless result["singular_project"]
          result[:project_durations] = hb.group(:project).duration_seconds
            .reject { |p, _| archived.include?(p) }.sort_by { |_, d| -d }.first(10).to_h
        end

        %i[language editor operating_system category].each do |f|
          next if result["singular_#{f}"]
          stats = hb.group(f).duration_seconds.each_with_object({}) do |(raw, dur), agg|
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

        result[:weekly_project_stats] = (0..11).to_h do |w|
          ws = w.weeks.ago.beginning_of_week
          [ ws.to_date.iso8601, hb.where(time: ws.to_f..w.weeks.ago.end_of_week.to_f)
              .group(:project).duration_seconds.reject { |p, _| archived.include?(p) } ]
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
    key = "user_#{current_user.id}_daily_durations_#{tz}"
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
