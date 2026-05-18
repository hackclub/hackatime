module DashboardData
  class Payload
    FILTER_OPTIONS_CACHE_VERSION = "v1".freeze

    def initialize(user:, params:, rollup_rows: nil)
      @user = user
      @params = params
      @rollup_rows = rollup_rows
      @rollup_refresh_scheduled = false
    end

    def payload(programming_goals_progress: [])
      {
        filterable_dashboard_data: filterable_dashboard_data,
        activity_graph: activity_graph_data,
        today_stats: today_stats_data,
        programming_goals_progress: programming_goals_progress
      }
    end

    def filterable_dashboard_data
      filters = dashboard_filters
      interval = @params[:interval]
      key = [ @user ] + filters.map { |field| @params[field] } + [ interval.to_s, @params[:from], @params[:to] ]

      if rollup_eligible?
        build_filterable_dashboard_data(filters, interval)
      else
        Rails.cache.fetch(key, expires_in: 5.minutes) do
          build_filterable_dashboard_data(filters, interval)
        end
      end
    end

    def activity_graph_data
      row = rollup_fragment_row(DashboardRollup::ACTIVITY_GRAPH_DIMENSION)
      return activity_graph_from_rollup(row) if activity_graph_rollup_valid?(row)

      schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
      live_activity_graph_data
    end

    def today_stats_data
      row = rollup_fragment_row(DashboardRollup::TODAY_STATS_DIMENSION)
      return today_stats_from_rollup(row) if today_stats_rollup_valid?(row)

      schedule_rollup_refresh(wait: 0.seconds) if rollups_available?
      live_today_stats_data
    end

    def rollup_eligible?
      @params[:interval].blank? &&
        @params[:from].blank? &&
        @params[:to].blank? &&
        dashboard_filters.none? { |field| @params[field].present? }
    end

    def rollups_available?
      DashboardRollup.table_exists?
    rescue ActiveRecord::StatementInvalid
      false
    end

    private

    def dashboard_filters
      DashboardData::Snapshots::GROUPED_DIMENSIONS
    end

    def build_filterable_dashboard_data(filters, interval)
      archived = @user.project_repo_mappings.archived.pluck(:project_name)
      filter_options = raw_filter_options
      result = rollup_result(filter_options, archived)

      result ||= query_result(filter_options, archived)
      result[:selected_interval] = interval.to_s
      result[:selected_from] = @params[:from].to_s
      result[:selected_to] = @params[:to].to_s
      filters.each { |field| result["selected_#{field}"] = @params[field]&.split(",") || [] }

      result
    end

    def raw_filter_options
      if rollup_eligible?
        options = rollup_filter_options
        return options if options
      end

      live_raw_filter_options
    end

    def live_raw_filter_options
      cache_keys = dashboard_filters.index_with do |field|
        "user_#{@user.id}_dashboard_filter_options_#{field}_#{FILTER_OPTIONS_CACHE_VERSION}"
      end

      reverse_lookup = cache_keys.invert

      cached = Rails.cache.fetch_multi(*cache_keys.values, expires_in: 15.minutes) do |cache_key|
        @user.heartbeats.distinct.pluck(reverse_lookup.fetch(cache_key)).compact_blank
      end

      cache_keys.transform_values { |cache_key| cached.fetch(cache_key, []) }
    end

    def rollup_filter_options
      return unless rollups_available?

      row = rollup_fragment_row(DashboardRollup::FILTER_OPTIONS_DIMENSION)
      payload = row&.payload
      unless payload.is_a?(Hash) && dashboard_filters.all? { |field| payload[field.to_s].is_a?(Array) || payload[field].is_a?(Array) }
        schedule_rollup_refresh(wait: 0.seconds)
        return
      end

      dashboard_filters.index_with do |field|
        Array(payload[field.to_s] || payload[field])
      end
    end

    def query_result(raw_filter_options, archived)
      heartbeats = @user.heartbeats
      result = filter_options_result(raw_filter_options, archived)
      helpers = ApplicationController.helpers

      Time.use_zone(@user.timezone) do
        dashboard_filters.each do |field|
          next unless @params[field].present?

          selected = @params[field].split(",")
          heartbeats = if field == :operating_system
            raw = raw_filter_options.fetch(:operating_system, []).select { |value| selected.include?(helpers.display_os_name(value)) }
            heartbeats.where(field => raw)
          elsif field == :editor
            raw = raw_filter_options.fetch(:editor, []).select { |value| selected.include?(helpers.display_editor_name(value)) }
            heartbeats.where(field => raw)
          elsif field == :language
            raw = raw_filter_options.fetch(:language, []).select { |language| selected.include?(language.categorize_language) }
            heartbeats.where(field => raw)
          else
            heartbeats.where(field => selected)
          end
          result["singular_#{field}"] = selected.length == 1
        end

        heartbeats = heartbeats.filter_by_time_range(@params[:interval], @params[:from], @params[:to])
        fill_aggregate_result(
          result: result,
          grouped_durations: DashboardData::Snapshots.grouped_durations_snapshot(heartbeats),
          total_time: heartbeats.duration_seconds,
          total_heartbeats: heartbeats.count,
          weekly_project_stats: DashboardData::Snapshots.weekly_project_stats(user: @user, scope: heartbeats),
          archived: archived
        )
      end

      result
    end

    def rollup_result(raw_filter_options, archived)
      snapshot = aggregate_rollup_snapshot
      return unless snapshot

      result = filter_options_result(raw_filter_options, archived)

      Time.use_zone(@user.timezone) do
        fill_aggregate_result(
          result: result,
          grouped_durations: snapshot.fetch(:grouped_durations),
          total_time: snapshot.fetch(:total_time),
          total_heartbeats: snapshot.fetch(:total_heartbeats),
          weekly_project_stats: snapshot.fetch(:weekly_project_stats),
          archived: archived
        )
      end

      result
    end

    def filter_options_result(raw_filter_options, archived)
      helpers = ApplicationController.helpers

      dashboard_filters.each_with_object({}) do |field, result|
        options = raw_filter_options.fetch(field, [])
        options = options.reject { |name| archived.include?(name) } if field == :project
        result[field] = options.map { |value|
          if field == :language then value.categorize_language
          elsif field == :editor then helpers.display_editor_name(value)
          elsif field == :operating_system then helpers.display_os_name(value)
          else value
          end
        }.uniq
      end
    end

    def fill_aggregate_result(result:, grouped_durations:, total_time:, total_heartbeats:, weekly_project_stats:, archived:)
      helpers = ApplicationController.helpers

      result[:total_time] = total_time
      result[:total_heartbeats] = total_heartbeats

      dashboard_filters.each do |field|
        stats = grouped_durations_for(grouped_durations, field, archived)
        result["top_#{field}"] = stats.max_by { |_, duration| duration }&.first
      end

      result["top_editor"] &&= helpers.display_editor_name(result["top_editor"])
      result["top_operating_system"] &&= helpers.display_os_name(result["top_operating_system"])
      result["top_language"] &&= helpers.display_language_name(result["top_language"])

      unless result["singular_project"]
        result[:project_durations] = grouped_durations_for(grouped_durations, :project, archived)
          .sort_by { |_, duration| -duration }.first(10).to_h
      end

      %i[language editor operating_system category].each do |field|
        next if result["singular_#{field}"]

        stats = grouped_durations.fetch(field, {}).each_with_object({}) do |(raw, duration), aggregate|
          next if raw.to_s.blank?

          key = if field == :language
            raw.to_s.categorize_language
          elsif %i[editor operating_system].include?(field)
            raw.to_s.downcase
          else
            raw.to_s
          end
          aggregate[key] = (aggregate[key] || 0) + duration
        end

        result["#{field}_stats"] = stats.sort_by { |_, duration| -duration }.first(10).map { |key, value|
          label = case field
          when :editor then helpers.display_editor_name(key)
          when :operating_system then helpers.display_os_name(key)
          when :language then helpers.display_language_name(key)
          else key
          end
          [ label, value ]
        }.to_h
      end

      if result["language_stats"].present?
        result[:language_colors] = LanguageUtils.colors_for(result["language_stats"].keys)
      end

      result[:weekly_project_stats] = weekly_project_stats.transform_values do |stats|
        stats.reject { |project, _| archived.include?(project) }
      end
    end

    def aggregate_rollup_snapshot
      return unless rollups_available?
      return unless rollup_eligible?

      total_row = rollup_total_row
      unless total_row
        schedule_rollup_refresh(wait: 0.seconds)
        return
      end

      schedule_rollup_refresh(wait: 0.seconds) if aggregate_rollup_stale?(total_row)

      {
        total_time: total_row.total_seconds,
        total_heartbeats: total_row.source_heartbeats_count.to_i,
        grouped_durations: dashboard_filters.index_with do |field|
          rollup_rows_by_dimension.fetch(field.to_s, []).to_h { |row| [ row.bucket, row.total_seconds ] }
        end,
        weekly_project_stats: rollup_weekly_project_stats(
          rollup_rows_by_dimension.fetch(DashboardData::Snapshots::WEEKLY_PROJECT_DIMENSION, [])
        )
      }
    end

    def rollup_rows
      return [] unless rollups_available?

      @rollup_rows ||= DashboardRollup.where(user_id: @user.id).to_a
    end

    def rollup_rows_by_dimension
      @rollup_rows_by_dimension ||= rollup_rows.group_by(&:dimension)
    end

    def rollup_fragment_row(dimension)
      rollup_rows_by_dimension.fetch(dimension.to_s, []).first
    end

    def rollup_total_row
      @rollup_total_row ||= rollup_rows.find(&:total_dimension?)
    end

    def aggregate_rollup_stale?(total_row)
      DashboardRollup.dirty?(@user.id) ||
        rollup_time_fingerprint(total_row.source_max_heartbeat_time) != rollup_source_max_heartbeat_time
    end

    def schedule_rollup_refresh(wait:)
      return if @rollup_refresh_scheduled

      DashboardRollupRefreshJob.schedule_for(@user.id, wait: wait)
      @rollup_refresh_scheduled = true
    end

    def activity_graph_rollup_valid?(row)
      payload = row&.payload
      return false unless payload.is_a?(Hash)

      start_date, end_date = DashboardData::Snapshots.activity_graph_date_range(@user.timezone)
      payload["timezone"] == @user.timezone &&
        payload["start_date"] == start_date &&
        payload["end_date"] == end_date &&
        payload["duration_by_date"].is_a?(Hash)
    end

    def today_stats_rollup_valid?(row)
      payload = row&.payload
      return false unless payload.is_a?(Hash)

      payload["timezone"] == @user.timezone &&
        payload["today_date"] == today_date &&
        payload.key?("todays_duration_seconds") &&
        payload["todays_language_categories"].is_a?(Array) &&
        payload["todays_editor_keys"].is_a?(Array)
    end

    def live_activity_graph_data
      timezone = @user.timezone
      snapshot = Rails.cache.fetch(@user.activity_graph_cache_key(timezone), expires_in: 1.minute) do
        DashboardData::Snapshots.activity_graph_snapshot(user: @user, scope: @user.heartbeats)
      end

      activity_graph_result(
        start_date: snapshot[:start_date],
        end_date: snapshot[:end_date],
        duration_by_date: snapshot[:duration_by_date],
        timezone: snapshot[:timezone]
      )
    end

    def activity_graph_from_rollup(row)
      payload = row.payload || {}

      activity_graph_result(
        start_date: payload["start_date"],
        end_date: payload["end_date"],
        duration_by_date: payload["duration_by_date"],
        timezone: payload["timezone"] || @user.timezone
      )
    end

    def activity_graph_result(start_date:, end_date:, duration_by_date:, timezone:)
      DashboardData::Snapshots.activity_graph_result(
        start_date: start_date,
        end_date: end_date,
        duration_by_date: duration_by_date,
        timezone: timezone
      )
    end

    def live_today_stats_data
      snapshot = DashboardData::Snapshots.today_stats_snapshot(user: @user, scope: @user.heartbeats)
      today_stats_result(
        todays_duration_seconds: snapshot[:todays_duration_seconds],
        todays_language_categories: snapshot[:todays_language_categories],
        todays_editor_keys: snapshot[:todays_editor_keys]
      )
    end

    def today_stats_from_rollup(row)
      payload = row.payload || {}

      today_stats_result(
        todays_duration_seconds: payload["todays_duration_seconds"],
        todays_language_categories: payload["todays_language_categories"],
        todays_editor_keys: payload["todays_editor_keys"]
      )
    end

    def today_stats_result(todays_duration_seconds:, todays_language_categories:, todays_editor_keys:)
      helpers = ApplicationController.helpers
      todays_languages = Array(todays_language_categories).filter_map do |language|
        helpers.display_language_name(language) if language.present?
      end
      todays_editors = Array(todays_editor_keys).filter_map do |editor|
        helpers.display_editor_name(editor) if editor.present?
      end
      todays_duration = todays_duration_seconds.to_i
      show_logged_time_sentence = todays_duration > 1.minute && (todays_languages.any? || todays_editors.any?)

      {
        show_logged_time_sentence: show_logged_time_sentence,
        todays_duration_display: helpers.short_time_detailed(todays_duration),
        todays_languages: todays_languages,
        todays_editors: todays_editors
      }
    end

    def today_date
      Time.use_zone(@user.timezone) { Date.current.iso8601 }
    end

    def rollup_source_max_heartbeat_time
      rollup_time_fingerprint(@user.heartbeats.maximum(:time))
    end

    def rollup_weekly_project_stats(rows)
      result = DashboardData::Snapshots.week_ranges(@user.timezone).to_h { |week_key, *_| [ week_key, {} ] }

      rows.each do |row|
        week_key, project = JSON.parse(row.bucket_value)
        next unless result.key?(week_key)

        result[week_key][project] = row.total_seconds
      end

      result
    end

    def rollup_time_fingerprint(timestamp)
      return if timestamp.nil?

      (timestamp * 1_000_000).round
    end

    def grouped_durations_for(grouped_durations, field, archived)
      stats = grouped_durations.fetch(field, {})
      return stats unless field == :project

      stats.reject { |project, _| archived.include?(project) }
    end
  end
end
