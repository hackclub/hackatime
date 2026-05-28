module My
  class HeartbeatsController < ApplicationController
    EXPORT_COOLDOWN = 10.minutes

    before_action :ensure_current_user
    before_action :ensure_no_ban, only: [ :export ]

    def export
      unless current_user.email_addresses.exists?
        return redirect_to my_settings_imports_exports_path, alert: "You need an email address on your account to export heartbeats."
      end

      if params[:all_data] == "true"
        return if export_rate_limited?

        HeartbeatExportJob.perform_later(current_user.id, all_data: true)
      else
        date_range = export_date_range_from_params
        return if date_range.nil?
        return if export_rate_limited?

        HeartbeatExportJob.perform_later(
          current_user.id,
          all_data: false,
          start_date: date_range[:start_date].iso8601,
          end_date: date_range[:end_date].iso8601
        )
      end

      redirect_to my_settings_imports_exports_path, notice: "Your export is being prepared and will be emailed to you."
    end

    private

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to view this page!!" unless current_user
    end

    def ensure_no_ban
      if current_user.trust_level == "red"
        redirect_to my_settings_path, alert: "Sorry, you are not permitted to this action."
      end
    end

    def export_date_range_from_params
      start_date = parse_iso8601_date(value: params[:start_date], default_value: 30.days.ago.to_date)
      return nil if start_date.nil?

      end_date = parse_iso8601_date(value: params[:end_date], default_value: Date.current)
      return nil if end_date.nil?

      if start_date > end_date
        redirect_to my_settings_imports_exports_path, alert: "Start date must be on or before end date."
        return nil
      end

      { start_date: start_date, end_date: end_date }
    end

    def parse_iso8601_date(value:, default_value:)
      return default_value if value.blank?
      Date.iso8601(value)
    rescue ArgumentError
      redirect_to my_settings_imports_exports_path, alert: "Invalid date format. Please use YYYY-MM-DD."
      nil
    end

    def export_rate_limited?
      return false unless recent_export_requested?

      redirect_to my_settings_imports_exports_path, alert: "Export requests are limited to once every 10 minutes."
      true
    end

    def recent_export_requested?
      GoodJob::Job
        .where(job_class: "HeartbeatExportJob")
        .where("created_at >= ?", EXPORT_COOLDOWN.ago)
        .where(
          "serialized_params -> 'arguments' -> 0 = to_jsonb(?::bigint)",
          current_user.id
        )
        .exists?
    end
  end
end
