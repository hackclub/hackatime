module Api
  class SummaryController < ApplicationController
    skip_before_action :verify_authenticity_token

    def index
      # Parse interval or date range
      date_range = determine_date_range(params[:interval], params[:range], params[:from], params[:to])
      return render json: { error: "Invalid date range" }, status: :bad_request unless date_range

      # Create parameters for WakatimeService
      start_date = date_range.begin.to_i
      end_date = date_range.end.to_i

      # Get user if specified
      if params[:user].present?
        user = User.find_by(slack_uid: params[:user])
        return render json: { error: "User not found" }, status: :not_found unless user
      end

      # Determine which summary elements we want
      specific_filters = [ :projects, :languages, :editors, :operating_systems, :machines, :categories, :branches, :entities, :labels ]

      # Create service instance with filters applied
      service = WakatimeService.new(
        user: user,
        specific_filters: specific_filters,
        allow_cache: true,
        limit: nil, # No limit for summary data
        start_date: start_date,
        end_date: end_date
      )

      # Get the summary data from WakatimeService
      wakatime_summary = service.generate_summary

      # Format for API response using ISO8601 timestamps and returning extra fields as {} if not provided
      summary = {
        user_id: params[:user],
        from: Time.parse(wakatime_summary[:start]).iso8601,
        to: Time.parse(wakatime_summary[:end]).iso8601,
        projects: wakatime_summary[:projects] ? wakatime_summary[:projects].map { |item| { key: item[:name].presence || "Other", total: item[:total_seconds] } } : [],
        languages: wakatime_summary[:languages] ? wakatime_summary[:languages].map { |item| { key: item[:name].presence || "Other", total: item[:total_seconds] } } : [],
        editors: wakatime_summary[:editors] || {},
        operating_systems: wakatime_summary[:operating_systems] || {},
        machines: wakatime_summary[:machines] || {},
        categories: wakatime_summary[:categories] || {},
        branches: wakatime_summary[:branches] || {},
        entities: wakatime_summary[:entities] || {},
        labels: wakatime_summary[:labels] || {}
      }

      render json: summary
    end

    private

    def determine_date_range(interval, range, from_date, to_date)
      timezone = "UTC"
      Time.use_zone(timezone) do
        now = Time.current

        if from_date.present? && to_date.present?
          begin
            from = Time.zone.parse(from_date).beginning_of_day
            to = Time.zone.parse(to_date).end_of_day
            return from..to
          rescue
            return nil
          end
        end

        interval ||= range # Allow range parameter as an alias for interval

        case interval
        when "today"
          now.beginning_of_day..now.end_of_day
        when "yesterday"
          (now - 1.day).beginning_of_day..(now - 1.day).end_of_day
        when "week", "7_days"
          now.beginning_of_week..now.end_of_week
        when "last_7_days"
          (now - 7.days).beginning_of_day..now.end_of_day
        when "month", "30_days"
          now.beginning_of_month..now.end_of_month
        when "last_30_days"
          (now - 30.days).beginning_of_day..now.end_of_day
        when "6_months"
          now.beginning_of_month - 5.months..now.end_of_month
        when "last_6_months"
          (now - 6.months).beginning_of_day..now.end_of_day
        when "year", "12_months"
          now.beginning_of_year..now.end_of_year
        when "last_12_months", "last_year"
          (now - 1.year).beginning_of_day..now.end_of_day
        when "any", "all_time", nil
          Time.at(0)..now.end_of_day
        else
          now.beginning_of_day..now.end_of_day # Default to today
        end
      end
    end

    def filter_heartbeats(heartbeats, params)
      heartbeats = heartbeats.where(project: params[:project]) if params[:project].present?
      heartbeats = heartbeats.where(language: params[:language]) if params[:language].present?
      heartbeats = heartbeats.where(editor: params[:editor]) if params[:editor].present?
      heartbeats = heartbeats.where(operating_system: params[:operating_system]) if params[:operating_system].present?
      heartbeats = heartbeats.where(machine: params[:machine]) if params[:machine].present?

      if params[:user].present?
        user = User.find_by(slack_uid: params[:user])
        heartbeats = heartbeats.where(user_id: user.id) if user
      end

      heartbeats
    end

    def calculate_summary(heartbeats, date_range)
      projects = {}
      languages = {}
      editors = {}
      operating_systems = {}
      machines = {}
      categories = {}
      branches = {}
      entities = {}
      labels = {}

      # Format summary items
      {
        from: date_range.begin.strftime("%Y-%m-%d %H:%M:%S.000"),
        to: date_range.end.strftime("%Y-%m-%d %H:%M:%S.000"),
        projects: format_summary_items(projects),
        languages: format_summary_items(languages),
        editors: format_summary_items(editors),
        operating_systems: format_summary_items(operating_systems),
        machines: format_summary_items(machines),
        categories: format_summary_items(categories),
        branches: format_summary_items(branches),
        entities: format_summary_items(entities),
        labels: format_summary_items(labels)
      }
    end

    def format_summary_items(items_hash)
      items_hash.map do |key, total_seconds|
        next if key.blank?
        {
          key: key,
          total_seconds: total_seconds,
          total: total_seconds,
          text: ApplicationController.helpers.short_time_simple(total_seconds),
          hours: total_seconds / 3600,
          minutes: (total_seconds % 3600) / 60,
          digital: ApplicationController.helpers.digital_time(total_seconds)
        }
      end.compact
    end
  end
end
