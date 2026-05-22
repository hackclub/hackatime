module Api
  class SummaryController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :set_user

    def index
      date_range = determine_date_range(
        params[:interval],
        params[:range],
        params[:from] || params[:start],
        params[:to] || params[:end]
      )
      return render_bad_request("Invalid date range") unless date_range

      service = WakatimeService.new(
        user: @user,
        specific_filters: %i[projects languages editors operating_systems machines categories branches entities labels],
        allow_cache: true,
        limit: nil,
        start_date: date_range.begin.to_i,
        end_date: date_range.end.to_i
      )

      wakatime_summary = service.generate_summary

      render json: {
        user_id: params[:user],
        from: Time.parse(wakatime_summary[:start]).iso8601,
        to: Time.parse(wakatime_summary[:end]).iso8601,
        projects: (wakatime_summary[:projects] || []).map { |i| { key: i[:name].presence || "Other", total: i[:total_seconds] } },
        languages: (wakatime_summary[:languages] || []).map { |i| { key: i[:name].presence || "Other", total: i[:total_seconds] } },
        editors: wakatime_summary[:editors] || {},
        operating_systems: wakatime_summary[:operating_systems] || {},
        machines: wakatime_summary[:machines] || {},
        categories: wakatime_summary[:categories] || {},
        branches: wakatime_summary[:branches] || {},
        entities: wakatime_summary[:entities] || {},
        labels: wakatime_summary[:labels] || {}
      }
    end

    private

    def set_user
      identifier = params[:user_id] || params[:user]
      return render_bad_request("Missing required parameter: user_id") unless identifier.present?

      @user = User.lookup_by_identifier(identifier)
      return render_not_found_json("User not found") unless @user
      render_forbidden("User has disabled public stats") unless @user.allow_public_stats_lookup
    end

    def determine_date_range(interval, range, from_date, to_date)
      Time.use_zone("UTC") do
        now = Time.current

        if from_date.present? && to_date.present?
          from = parse_explicit_date(from_date, boundary: :start)
          to = parse_explicit_date(to_date, boundary: :end)
          return nil if from.nil? || to.nil?
          return from..to
        end

        case (interval || range)
        when "today" then now.beginning_of_day..now.end_of_day
        when "yesterday" then (now - 1.day).beginning_of_day..(now - 1.day).end_of_day
        when "week", "7_days" then now.beginning_of_week..now.end_of_week
        when "last_7_days" then (now - 7.days).beginning_of_day..now.end_of_day
        when "month", "30_days" then now.beginning_of_month..now.end_of_month
        when "last_30_days" then (now - 30.days).beginning_of_day..now.end_of_day
        when "6_months" then now.beginning_of_month - 5.months..now.end_of_month
        when "last_6_months" then (now - 6.months).beginning_of_day..now.end_of_day
        when "year", "12_months" then now.beginning_of_year..now.end_of_year
        when "last_12_months", "last_year" then (now - 1.year).beginning_of_day..now.end_of_day
        when "any", "all_time", nil then Time.at(0)..now.end_of_day
        else now.beginning_of_day..now.end_of_day
        end
      end
    end

    def parse_explicit_date(raw_value, boundary:)
      parsed = Time.zone.parse(raw_value.to_s)
      return nil if parsed.nil?
      boundary == :start ? parsed.beginning_of_day : parsed.end_of_day
    rescue ArgumentError, TypeError
      nil
    end
  end
end
