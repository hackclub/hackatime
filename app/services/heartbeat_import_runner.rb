require "fileutils"
require "securerandom"

class HeartbeatImportRunner
  STATUS_TTL = 12.hours
  PROGRESS_INTERVAL = 250

  def self.start(user:, uploaded_file:)
    import_id = SecureRandom.uuid
    file_path = persist_uploaded_file(uploaded_file, import_id)

    write_status(user_id: user.id, import_id: import_id, attributes: {
      state: "queued",
      progress_percent: 0,
      processed_count: 0,
      total_count: nil,
      imported_count: nil,
      skipped_count: nil,
      errors_count: 0,
      message: "Queued import."
    })

    Thread.new(user.id, import_id, file_path) do |user_id, thread_import_id, thread_file_path|
      Thread.current.report_on_exception = false
      run_import(user_id: user_id, import_id: thread_import_id, file_path: thread_file_path)
    end

    import_id
  end

  def self.status(user:, import_id:)
    Rails.cache.read(cache_key(user.id, import_id))
  end

  def self.run_import(user_id:, import_id:, file_path:)
    ActiveRecord::Base.connection_pool.with_connection do
      user = User.find_by(id: user_id)
      unless user
        write_status(user_id: user_id, import_id: import_id, attributes: {
          state: "failed",
          progress_percent: 0,
          message: "User not found.",
          finished_at: Time.current.iso8601
        })
        return
      end

      write_status(user_id: user_id, import_id: import_id, attributes: {
        state: "counting",
        message: "Counting heartbeats...",
        started_at: Time.current.iso8601
      })

      file_content = File.read(file_path).force_encoding("UTF-8")
      total_count = HeartbeatImportService.count_heartbeats(file_content)

      if total_count.zero?
        write_status(user_id: user_id, import_id: import_id, attributes: {
          state: "failed",
          progress_percent: 0,
          total_count: 0,
          message: "No heartbeats found in file.",
          finished_at: Time.current.iso8601
        })
        return
      end

      write_status(user_id: user_id, import_id: import_id, attributes: {
        state: "running",
        total_count: total_count,
        progress_percent: 0,
        processed_count: 0,
        message: "Importing heartbeats..."
      })

      result = HeartbeatImportService.import_from_file(
        file_content,
        user,
        progress_interval: PROGRESS_INTERVAL,
        on_progress: lambda { |processed_count|
          progress = [ ((processed_count.to_f / total_count) * 100).round, 100 ].min
          write_status(user_id: user_id, import_id: import_id, attributes: {
            state: "running",
            progress_percent: progress,
            processed_count: processed_count,
            total_count: total_count,
            message: "Importing heartbeats..."
          })
        }
      )

      if result[:success]
        write_status(user_id: user_id, import_id: import_id, attributes: {
          state: "completed",
          progress_percent: 100,
          processed_count: result[:total_count],
          total_count: result[:total_count],
          imported_count: result[:imported_count],
          skipped_count: result[:skipped_count],
          errors_count: result[:errors].length,
          message: build_success_message(result),
          finished_at: Time.current.iso8601
        })
      else
        write_status(user_id: user_id, import_id: import_id, attributes: {
          state: "failed",
          progress_percent: 0,
          imported_count: result[:imported_count],
          skipped_count: result[:skipped_count],
          errors_count: result[:errors].length,
          message: "Import failed: #{result[:error]}",
          finished_at: Time.current.iso8601
        })
      end
    end
  rescue => e
    write_status(user_id: user_id, import_id: import_id, attributes: {
      state: "failed",
      message: "Import failed: #{e.message}",
      finished_at: Time.current.iso8601
    })
  ensure
    FileUtils.rm_f(file_path) if file_path.present?
    ActiveRecord::Base.clear_active_connections!
  end

  def self.write_status(user_id:, import_id:, attributes:)
    key = cache_key(user_id, import_id)
    existing = Rails.cache.read(key) || {}
    payload = existing.merge(attributes).merge(
      import_id: import_id,
      updated_at: Time.current.iso8601
    )

    Rails.cache.write(key, payload, expires_in: STATUS_TTL)
    payload
  end

  def self.persist_uploaded_file(uploaded_file, import_id)
    tmp_dir = Rails.root.join("tmp", "heartbeat_imports")
    FileUtils.mkdir_p(tmp_dir)

    ext = File.extname(uploaded_file.original_filename.to_s)
    ext = ".json" if ext.blank?
    file_path = tmp_dir.join("#{import_id}#{ext}")
    FileUtils.cp(uploaded_file.tempfile.path, file_path)

    file_path.to_s
  end

  def self.cache_key(user_id, import_id)
    "heartbeat_import_status:user:#{user_id}:import:#{import_id}"
  end

  def self.build_success_message(result)
    message = "Imported #{result[:imported_count]} out of #{result[:total_count]} heartbeats in #{result[:time_taken]}s."
    return message if result[:skipped_count].zero?

    "#{message} Skipped #{result[:skipped_count]} duplicate heartbeats."
  end
end
