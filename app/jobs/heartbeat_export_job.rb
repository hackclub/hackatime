require "zip"

class HeartbeatExportJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_export_job_#{arguments.first}" }
  )

  HEARTBEAT_EXPORT_FIELDS = %i[
    id entity type category project language editor operating_system machine branch
    user_agent is_write line_additions line_deletions lineno lines cursorpos dependencies
    source_type ai_model ai_session ai_subscription_plan ai_input_tokens ai_output_tokens
    ai_prompt_length ai_line_changes human_line_changes
  ].freeze

  def perform(user_id, all_data:, start_date: nil, end_date: nil)
    user = User.find_by(id: user_id)
    return if user.nil?

    recipient_email = user.email_addresses.order(:id).pick(:email)
    unless recipient_email.present?
      Rails.logger.warn("Skipping heartbeat export for user #{user.id}: no email address found")
      return
    end

    if all_data
      heartbeats = user.heartbeats
      first_time, last_time = user.heartbeats.pick(Arel.sql("MIN(time), MAX(time)"))
      if first_time && last_time
        start_date = Time.at(first_time).to_date
        end_date = Time.at(last_time).to_date
      else
        start_date = end_date = Date.current
      end
    else
      start_date = Date.iso8601(start_date)
      end_date = Date.iso8601(end_date)
      heartbeats = user.heartbeats
        .where("time >= ? AND time <= ?", start_date.beginning_of_day.to_f, end_date.end_of_day.to_f)
    end

    user_identifier = user.slack_uid.presence || "user_#{user.id}"
    json_filename = "heartbeats_#{user_identifier}_#{start_date.strftime("%Y%m%d")}_#{end_date.strftime("%Y%m%d")}.json"
    zip_filename = "#{File.basename(json_filename, ".json")}.zip"

    Tempfile.create([ "heartbeat_export", ".json" ]) do |file|
      write_export_json(file, heartbeats, start_date, end_date)
      file.flush

      Tempfile.create([ "heartbeat_export", ".zip" ]) do |zip_file|
        Zip::File.open(zip_file.path, create: true) { |archive| archive.add(json_filename, file.path) }

        blob = File.open(zip_file.path, "rb") do |zip_io|
          ActiveStorage::Blob.create_and_upload!(
            io: zip_io,
            filename: zip_filename,
            content_type: "application/zip",
            metadata: { heartbeat_export: true, user_id: user.id }
          )
        end

        HeartbeatExportCleanupJob.set(wait: 7.days).perform_later(blob.id)
        HeartbeatExportMailer.export_ready(
          user,
          recipient_email:,
          blob_signed_id: blob.signed_id,
          filename: zip_filename
        ).deliver_now
      end
    end
  rescue ArgumentError => e
    report_error(e, message: "Heartbeat export failed for user #{user_id}")
  end

  private

  # Streams the export document instead of materialising every heartbeat in
  # memory, so exports for heavy users stay within worker memory limits.
  def write_export_json(file, heartbeats, start_date, end_date)
    export_info = {
      exported_at: Time.current.iso8601,
      date_range: { start_date: start_date.iso8601, end_date: end_date.iso8601 },
      total_heartbeats: heartbeats.count,
      total_duration_seconds: heartbeats.duration_seconds
    }

    file.write(%({"export_info":#{export_info.to_json},"heartbeats":[))
    first = true
    heartbeats.find_each do |hb|
      file.write(",") unless first
      first = false
      file.write(export_row(hb).to_json)
    end
    file.write("]}")
  end

  def export_row(hb)
    HEARTBEAT_EXPORT_FIELDS.index_with { |f| hb.public_send(f) }.merge(
      time: Time.at(hb.time).iso8601,
      created_at: hb.created_at.iso8601,
      updated_at: hb.updated_at.iso8601
    )
  end
end
