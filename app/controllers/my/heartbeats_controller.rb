module My
  class HeartbeatsController < ApplicationController
    before_action :ensure_current_user
    before_action :ensure_no_ban, only: [ :export ]

    def export
      unless current_user.email_addresses.exists?
        redirect_to my_settings_data_path, alert: "You need an email address on your account to export heartbeats."
        return
      end

      all_data = params[:all_data] == "true"

      if all_data
        HeartbeatExportJob.perform_later(current_user.id, all_data: true)
      else
        date_range = export_date_range_from_params
        return if date_range.nil?

        HeartbeatExportJob.perform_later(
          current_user.id,
          all_data: false,
          start_date: date_range[:start_date].iso8601,
          end_date: date_range[:end_date].iso8601
        )
      end

      redirect_to my_settings_data_path, notice: "Your export is being prepared and will be emailed to you."
    end

    def import
      unless Rails.env.development?
        redirect_to my_settings_path, alert: "Hey you! This is noit a dev env, STOP DOING THIS!!!!!) Also, idk why this is happning, you should not be able to see this button hmm...."
        return
      end

      unless params[:heartbeat_file].present?
        redirect_to my_settings_path, alert: "pls select a file to import"
        return
      end

      file = params[:heartbeat_file]

      unless file.content_type == "application/json" || file.original_filename.ends_with?(".json")
        redirect_to my_settings_path, alert: "pls upload only json (download from the button above it)"
        return
      end

      begin
        file_content = file.read.force_encoding("UTF-8")
      rescue => e
        redirect_to my_settings_path, alert: "error reading file: #{e.message}"
        return
      end

      result = HeartbeatImportService.import_from_file(file_content, current_user)

      if result[:success]
        message = "Imported #{result[:imported_count]} out of #{result[:total_count]} heartbeats in #{result[:time_taken]}s"
        if result[:skipped_count] > 0
          message += " (#{result[:skipped_count]} skipped cause they were duplicates)"
        end
        if result[:errors].any?
          error_count = result[:errors].length
          if error_count <= 3
            message += ". Errors occurred: #{result[:errors].join("; ")}"
          else
            message += ". #{error_count} errors occurred. First few: #{result[:errors].first(2).join("; ")}..."
          end
        end
        redirect_to root_path, notice: message
      else
        error_message = "Import failed: #{result[:error]}"
        if result[:errors].any? && result[:errors].length > 1
          error_message += "Errors: #{result[:errors][1..2].join("; ")}"
        end
        redirect_to my_settings_path, alert: error_message
      end
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
      start_date = parse_iso8601_date(
        value: params[:start_date],
        default_value: 30.days.ago.to_date
      )
      return nil if start_date.nil?

      end_date = parse_iso8601_date(
        value: params[:end_date],
        default_value: Date.current
      )
      return nil if end_date.nil?

      if start_date > end_date
        redirect_to my_settings_data_path, alert: "Start date must be on or before end date."
        return nil
      end

      { start_date: start_date, end_date: end_date }
    end

    def parse_iso8601_date(value:, default_value:)
      return default_value if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      redirect_to my_settings_data_path, alert: "Invalid date format. Please use YYYY-MM-DD."
      nil
    end
  end
end
