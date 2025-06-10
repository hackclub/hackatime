require "fileutils"
require "open-uri"

class OneTime::MigrateWakatimecomHeartbeatsJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  # only allow one instance of this job to run at a time
  good_job_control_concurrency_with(
    key: -> { "migrate_wakatimecom_heartbeats_job_#{arguments.first}" },
    total_limit: 1,
  )

  def perform(user_id)
    @user = User.find(user_id)
    @api_key = WakatimeMirror.find_by(endpoint_url: "https://wakatime.com/api/v1", user_id: @user.id)&.encrypted_api_key
    import_heartbeats
  end

  private

  def import_heartbeats
    puts "starting wakatime.com heartbeats import for user #{@user.id}"

    # get dump once to check if there's already one.
    # in development i've already created one and don't want to keep spamming dumps
    # (it's also really slow for me, my entire coding career is in there)
    dump = get_dumps

    if dump["status"] != "Completed" && !wakatime_json_exists?
      create_dump
      while true
        sleep 5
        dump = get_dumps
        puts "wakatime.com import for #{@user.id} is at #{dump['percent_complete']}%"
        break if dump["status"] == "Completed"
      end
    end

    output_path = download(dump)
    machines = get_machines
    agents = get_agents

    existing_heartbeats = Heartbeat.where(user_id: @user.id)
      .select(:entity, :type, :project, :branch, :language, :time)
      .map { |h| generate_dedup_key(h.entity, h.type, h.project, h.branch, h.language, h.time) }
      .to_set
    
    # this could explode, let's see how it ends up.
    parsed_json = JSON.parse(File.read(output_path))
    parsed_json = parsed_json["days"].select { |day| day["heartbeats"].any? }
    puts "found #{parsed_json.size} days with heartbeats"
        
    heartbeats_to_insert = []
    parsed_json.each do |day|
      day["heartbeats"].each do |wh|
        next if wh["category"] == "browsing"
        agent = agents.find { |a| a["id"] == wh["user_agent_id"] }
        
        attrs = {
          user_id: @user.id,
          branch: wh["branch"],
          category: wh["category"],
          dependencies: wh["dependencies"],
          entity: wh["entity"],
          is_write: wh["is_write"],
          language: wh["language"],
          project: wh["project"],
          time: wh["time"],
          type: wh["type"],
          machine: machines.find { |m| m["id"] == wh["machine_name_id"] }&.dig("name"),
          editor: agent&.dig("editor"),
          operating_system: agent&.dig("os"),
          cursorpos: wh["cursorpos"],
          lineno: wh["lineno"],
          lines: wh["lines"],
          created_at: wh["created_at"],
          source_type: 3 # wakatimecom_import
        }

        attrs[:fields_hash] = Heartbeat.generate_fields_hash(attrs)
        
        dedup_key = generate_dedup_key(attrs[:entity], attrs[:type], attrs[:project], attrs[:branch], attrs[:language], attrs[:time])
        if existing_heartbeats.include?(dedup_key)
          next
        end
        
        heartbeats_to_insert << attrs
      end
    end

    # deduplicate heartbeats
    heartbeats_to_insert = heartbeats_to_insert.uniq { |attrs| attrs[:fields_hash] }
    puts "attempting to insert #{heartbeats_to_insert.size} heartbeats..."

    if heartbeats_to_insert.any?
      begin
        result = Heartbeat.upsert_all(
          heartbeats_to_insert,
          unique_by: :fields_hash
        )
        puts "inserted #{result.rows.size} heartbeats."
      rescue => e
        puts "error during insert: #{e.class} - #{e.message}"
        puts e.backtrace.join("\n")
      end
    else
      puts "no new heartbeats to insert."
    end

    # FileUtils.rm(output_path)
    puts "finished wakatime.com heartbeats import for user #{@user.id}"
  end

  def get_dumps
    auth_token = Base64.strict_encode64("#{@api_key}:")
    response = HTTP.auth("Basic #{auth_token}")
      .get("https://api.wakatime.com/api/v1/users/current/data_dumps")

    if response.status.success?
      dumps = JSON.parse(response.body)["data"].find { |dump| dump["type"] == "heartbeats" }
      dumps || {}
    else
      puts "Failed to fetch Wakatime.com data dumps: #{response.status} - #{response.body}"
      {}
    end
  end

  def create_dump
    auth_token = Base64.strict_encode64("#{@api_key}:")
    HTTP.auth("Basic #{auth_token}")
      .post("https://api.wakatime.com/api/v1/users/current/data_dumps",
        json: {
          type: "heartbeats",
          email_when_finished: false
        }
      )
  end

  def download(dump)
    output_dir = Rails.root.join("storage", "wakatime_dumps")
    FileUtils.mkdir_p(output_dir)
    output_path = output_dir.join("wakatime_heartbeats_#{@user.id}.json")
    # check if it doesnt exist
    # this is because i've been working on this during a roadtrip without unlimited data
    if wakatime_json_exists?
      puts "file already exists, skipping download"
      return output_path
    end

    puts "downloading wakatime.com heartbeats dump for user #{@user.id}"
    File.open(output_path, "wb") do |file|
      # i don't get why with HTTP it doesn't work...
      file.write(URI.open(dump["download_url"]).read)
    end

    puts "wakatime.com heartbeats saved to #{output_path} for user #{@user.id}"
    output_path
  end

  def get_machines
    auth_token = Base64.strict_encode64("#{@api_key}:")
    all_machines = []
    page = 1
    
    loop do
      response = HTTP.auth("Basic #{auth_token}")
        .get("https://api.wakatime.com/api/v1/users/current/machine_names", params: { page: page })
      
      if response.status.success?
        data = JSON.parse(response.body)
        machines = data["data"]
        all_machines.concat(machines)
        
        # Check if there are more pages
        if data["next_page"]
          sleep 1 # fricken ratelimits!!!
          page += 1
        else
          break
        end
      else
        puts "failed to fetch wakatime.com machines: #{response.status} - #{response.body}"
        break
      end
    end
    
    puts "fetched #{all_machines.size} machines total"
    all_machines
  end

  def get_agents # basically the editors
    auth_token = Base64.strict_encode64("#{@api_key}:")
    all_agents = []
    page = 1
    
    loop do
      response = HTTP.auth("Basic #{auth_token}")
        .get("https://api.wakatime.com/api/v1/users/current/user_agents", params: { page: page })
      
      if response.status.success?
        data = JSON.parse(response.body)
        agents = data["data"]
        all_agents.concat(agents)
        
        # Check if there are more pages
        if data["next_page"]
          sleep 1 # fricken ratelimits!!!
          page += 1
        else
          break
        end
      else
        puts "failed to fetch wakatime.com user agents: #{response.status} - #{response.body}"
        break
      end
    end
    
    puts "fetched #{all_agents.size} user agents total"
    all_agents
  end

  def wakatime_json_exists?
    output_dir = Rails.root.join("storage", "wakatime_dumps")
    output_path = output_dir.join("wakatime_heartbeats_#{@user.id}.json")
    File.exist?(output_path)
  end

  def generate_dedup_key(entity, type, project, branch, language, time)
    "#{entity}-#{type}-#{project}-#{branch}-#{language}-#{time}"
  end
end
