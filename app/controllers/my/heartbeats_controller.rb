module My
  class HeartbeatsController < ApplicationController
    before_action :ensure_current_user


    def export
      all_data = params[:all_data] == "true"
      if all_data
        heartbeats = current_user.heartbeats.order(time: :asc)
        if heartbeats.any?
          start_date = Time.at(heartbeats.first.time).to_date
          end_date = Time.at(heartbeats.last.time).to_date
        else
          start_date = Date.current
          end_date = Date.current
        end
      else
        start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
        end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
        start_time = start_date.beginning_of_day.to_f
        end_time = end_date.end_of_day.to_f

        heartbeats = current_user.heartbeats
          .where("time >= ? AND time <= ?", start_time, end_time)
          .order(time: :asc)
      end


      export_data = {
        export_info: {
          exported_at: Time.current.iso8601,
          date_range: {
            start_date: start_date.iso8601,
            end_date: end_date.iso8601
          },
          total_heartbeats: heartbeats.count,
          total_duration_seconds: heartbeats.duration_seconds
        },
        heartbeats: heartbeats.map do |heartbeat|
          {
            id: heartbeat.id,
            time: Time.at(heartbeat.time).iso8601,
            entity: heartbeat.entity,
            type: heartbeat.type,
            category: heartbeat.category,
            project: heartbeat.project,
            language: heartbeat.language,
            editor: heartbeat.editor,
            operating_system: heartbeat.operating_system,
            machine: heartbeat.machine,
            branch: heartbeat.branch,
            user_agent: heartbeat.user_agent,
            is_write: heartbeat.is_write,
            line_additions: heartbeat.line_additions,
            line_deletions: heartbeat.line_deletions,
            lineno: heartbeat.lineno,
            lines: heartbeat.lines,
            cursorpos: heartbeat.cursorpos,
            dependencies: heartbeat.dependencies,
            source_type: heartbeat.source_type,
            created_at: heartbeat.created_at.iso8601,
            updated_at: heartbeat.updated_at.iso8601
          }
        end
      }

      filename = "heartbeats_#{current_user.slack_uid}_#{start_date.strftime('%Y%m%d')}_#{end_date.strftime('%Y%m%d')}.json"

      respond_to do |format|
        format.json {
          send_data export_data.to_json,
                    filename: filename,
                    type: "application/json",
                    disposition: "attachment"
        }
      end
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

      unless file.content_type == 'application/json' || file.original_filename.ends_with?('.json')
        redirect_to my_settings_path, alert: "pls upload only json (download from the button above it)"
        return
      end

      begin
        file_content = file.read.force_encoding('UTF-8')
      rescue => e
        redirect_to my_settings_path, alert: "error reading file: #{e.message}"
        return
      end

      result = HeartbeatImportService.import_from_file(file_content, current_user)

      if result[:success]
        message = "Imported #{result[:imported_count]} out of #{result[:total_count]} heartbeats"
        if result[:skipped_count] > 0
          message += " (#{result[:skipped_count]} skipped cause they were duplicates)"
        end
        if result[:errors].any?
          error_count = result[:errors].length
          if error_count <= 3
            message += ". Errors occurred: #{result[:errors].join('; ')}"
          else
            message += ". #{error_count} errors occurred. First few: #{result[:errors].first(2).join('; ')}..."
          end
        end
        redirect_to root_path, notice: message
      else
        error_message = "Import failed: #{result[:error]}"
        if result[:errors].any? && result[:errors].length > 1
          error_message += "Errors: #{result[:errors][1..2].join('; ')}"
        end
        redirect_to my_settings_path, alert: error_message
      end
    end

    private

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to view this page!!" unless current_user
    end
  end
end
