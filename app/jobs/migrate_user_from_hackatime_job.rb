class MigrateUserFromHackatimeJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # only allow one instance of this job to run at a time
  good_job_control_concurrency_with(
    key: -> { "migrate_user_from_hackatime_job_#{arguments.first}" },
    total_limit: 1,
  )

  def perform(user_id)
    return unless Flipper.enabled?(:hackatime_v1_import)

    @user = User.find(user_id)
    # Import from Hackatime
    return unless @user.slack_uid.present?
    return unless Hackatime::User.exists?(id: @user.slack_uid)

    import_api_keys
    import_heartbeats

    # We don't want to trigger notifications due to extra time from importing
    # heartbeats, so reset
    reset_sailors_log
  end

  private

  def reset_sailors_log
    return unless @user.sailors_log.present?
    @user.sailors_log.update!(projects_summary: {})
    @user.sailors_log.send(:initialize_projects_summary)
  end

  def import_heartbeats
    # create Heartbeat records for each Hackatime::Heartbeat in batches of 1000 as upsert

    Hackatime::Heartbeat.where(user_id: @user.slack_uid).find_in_batches do |batch|
      records_to_upsert = batch.map do |heartbeat|
        # Convert dependencies to proper array format or default to empty array
        dependencies = if heartbeat.dependencies.is_a?(String)
          # If it's a string, try to parse it as JSON, fallback to empty array
          begin
            JSON.parse(heartbeat.dependencies)
          rescue JSON::ParserError
            # If it can't be parsed as JSON, split by comma and clean up
            heartbeat.dependencies.gsub(/[{}]/, "").split(",").map(&:strip)
          end
        else
          heartbeat.dependencies.presence || []
        end

        attrs = {
          user_id: @user.id,
          time: heartbeat.time,
          project: heartbeat.project,
          branch: heartbeat.branch,
          category: heartbeat.category,
          dependencies: dependencies,
          editor: heartbeat.editor,
          entity: heartbeat.entity,
          language: heartbeat.language,
          machine: heartbeat.machine,
          operating_system: heartbeat.operating_system,
          type: heartbeat.type,
          user_agent: heartbeat.user_agent,
          line_additions: heartbeat.line_additions,
          line_deletions: heartbeat.line_deletions,
          lineno: heartbeat.line_number,
          lines: heartbeat.lines,
          cursorpos: heartbeat.cursor_position,
          project_root_count: heartbeat.project_root_count,
          is_write: heartbeat.is_write,
          source_type: :wakapi_import
          # raw_data: heartbeat.attributes.slice(*Heartbeat.indexed_attributes)
        }

        {
          **attrs,
          fields_hash: Heartbeat.generate_fields_hash(attrs)
        }
      end

      # dedupe records by fields_hash
      records_to_upsert = records_to_upsert.group_by { |r| r[:fields_hash] }.map do |_, records|
        records.max_by { |r| r[:time] }
      end

      Heartbeat.upsert_all(records_to_upsert, unique_by: [ :fields_hash ])
    end
  end

  def import_api_keys
    puts "Importing API keys"
    hackatime_user = Hackatime::User.find(@user.slack_uid)
    return if hackatime_user.nil?

    ApiKey.upsert(
      {
        user_id: @user.id,
        name: "Imported from Hackatime",
        token: hackatime_user.api_key
      },
      unique_by: [ :user_id, :name ]
    )
  end
end
