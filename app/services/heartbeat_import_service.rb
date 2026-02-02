class HeartbeatImportService
  def self.import_from_file(file_content, user)
    unless Rails.env.development?
      raise StandardError, "Not dev env, not running"
    end

    begin
      parsed_data = JSON.parse(file_content)
    rescue JSON::ParserError => e
      raise StandardError, "Not json: #{e.message}"
    end

    unless parsed_data.is_a?(Hash) && parsed_data["heartbeats"].is_a?(Array)
      raise StandardError, "Not correct format, download from /my/settings on the offical hackatime then import here"
    end

    heartbeats_data = parsed_data["heartbeats"]
    imported_count = 0
    skipped_count = 0
    errors = []
    cc = 817263
    heartbeats_data.each_slice(100) do |batch|
      records_to_upsert = []

      batch.each_with_index do |heartbeat_data, index|
        begin
          time_value = if heartbeat_data["time"].is_a?(String)
            Time.parse(heartbeat_data["time"]).to_f
          else
            heartbeat_data["time"].to_f
          end

          attrs = {
            user_id: user.id,
            time: time_value,
            entity: heartbeat_data["entity"],
            type: heartbeat_data["type"],
            category: heartbeat_data["category"] || "coding",
            project: heartbeat_data["project"],
            language: heartbeat_data["language"],
            editor: heartbeat_data["editor"],
            operating_system: heartbeat_data["operating_system"],
            machine: heartbeat_data["machine"],
            branch: heartbeat_data["branch"],
            user_agent: heartbeat_data["user_agent"],
            is_write: heartbeat_data["is_write"] || false,
            line_additions: heartbeat_data["line_additions"],
            line_deletions: heartbeat_data["line_deletions"],
            lineno: heartbeat_data["lineno"],
            lines: heartbeat_data["lines"],
            cursorpos: heartbeat_data["cursorpos"],
            dependencies: heartbeat_data["dependencies"] || [],
            project_root_count: heartbeat_data["project_root_count"],
            source_type: :wakapi_import
          }
          attrs[:raw_data] = heartbeat_data.slice(*Heartbeat.indexed_attributes) unless Flipper.enabled?(:skip_heartbeat_raw_data)

          attrs[:fields_hash] = Heartbeat.generate_fields_hash(attrs)
          print(attrs[:fields_hash])
          print("\n")
          records_to_upsert << attrs

        rescue => e
          errors << "Row #{index + 1}: #{e.message}"
          next
        end
      end

      if records_to_upsert.any?
        print("importing!!!!!!!!!!!!!!!!!!!!!!")
        print("\n")
        begin
          records_to_upsert = records_to_upsert.group_by { |r| r[:fields_hash] }.map do |_, records|
            records.max_by { |r| r[:time] }
          end
          records_to_upsert = Heartbeat.batch_resolve_dimensions(records_to_upsert)
          result = Heartbeat.upsert_all(records_to_upsert, unique_by: [ :fields_hash ])
          imported_count += result.length
        rescue => e
          errors << "Import error: #{e.message}"
          print(e.message)
          print("\n")
        end
      end
    end

    {
      success: true,
      imported_count: imported_count,
      total_count: heartbeats_data.length,
      skipped_count: heartbeats_data.length - imported_count,
      errors: errors
    }

  rescue => e
    {
      success: false,
      error: e.message,
      imported_count: 0,
      total_count: 0,
      skipped_count: 0,
      errors: [ e.message ]
    }
  end
end
