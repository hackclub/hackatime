require "zip"

class HeartbeatExportJob < ApplicationJob
  queue_as :default

  def perform(user_id, all_data:, start_date: nil, end_date: nil)
    user = User.find_by(id: user_id)
    return if user.nil?

    recipient_email = user.email_addresses.order(:id).pick(:email)
    unless recipient_email.present?
      Rails.logger.warn("Skipping heartbeat export for user #{user.id}: no email address found")
      return
    end

    if all_data
      heartbeats = user.heartbeats.order(time: :asc)
      first_time, last_time = user.heartbeats.pick(Arel.sql("MIN(time), MAX(time)"))

      if first_time && last_time
        start_date = Time.at(first_time).to_date
        end_date = Time.at(last_time).to_date
      else
        start_date = Date.current
        end_date = Date.current
      end
    else
      start_date = Date.iso8601(start_date)
      end_date = Date.iso8601(end_date)
      start_time = start_date.beginning_of_day.to_f
      end_time = end_date.end_of_day.to_f

      heartbeats = user.heartbeats
        .where("time >= ? AND time <= ?", start_time, end_time)
        .order(time: :asc)
    end

    export_data = build_export_data(heartbeats, start_date, end_date)
    user_identifier = user.slack_uid.presence || "user_#{user.id}"
    json_filename = "heartbeats_#{user_identifier}_#{start_date.strftime("%Y%m%d")}_#{end_date.strftime("%Y%m%d")}.json"
    zip_filename = "#{File.basename(json_filename, ".json")}.zip"

    Tempfile.create([ "heartbeat_export", ".json" ]) do |file|
      file.write(export_data.to_json)
      file.rewind

      Tempfile.create([ "heartbeat_export", ".zip" ]) do |zip_file|
        Zip::File.open(zip_file.path, create: true) do |archive|
          archive.add(json_filename, file.path)
        end

        blob = File.open(zip_file.path, "rb") do |zip_io|
          ActiveStorage::Blob.create_and_upload!(
            io: zip_io,
            filename: zip_filename,
            content_type: "application/zip",
            metadata: {
              heartbeat_export: true,
              user_id: user.id
            }
          )
        end

        HeartbeatExportCleanupJob.set(wait: 7.days).perform_later(blob.id)

        HeartbeatExportMailer.export_ready(
          user,
          recipient_email: recipient_email,
          blob_signed_id: blob.signed_id,
          filename: zip_filename
        ).deliver_now
      end
    end
  rescue ArgumentError => e
    Rails.logger.error("Heartbeat export failed for user #{user_id}: #{e.message}")
  end

  private

  def build_export_data(heartbeats, start_date, end_date)
    {
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
  end
end
