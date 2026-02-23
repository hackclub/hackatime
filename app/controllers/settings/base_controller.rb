class Settings::BaseController < InertiaController
  layout "inertia"

  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user
  before_action :prepare_settings_page

  private

  def render_settings_page(active_section:, settings_update_path:, status: :ok)
    render inertia: settings_component_for(active_section), props: settings_page_props(
      active_section: active_section,
      settings_update_path: settings_update_path
    ), status: status
  end

  def settings_component_for(active_section)
    {
      "profile" => "Users/Settings/Profile",
      "integrations" => "Users/Settings/Integrations",
      "access" => "Users/Settings/Access",
      "goals" => "Users/Settings/Goals",
      "badges" => "Users/Settings/Badges",
      "data" => "Users/Settings/Data",
      "admin" => "Users/Settings/Admin"
    }.fetch(active_section.to_s, "Users/Settings/Profile")
  end

  def prepare_settings_page
    @is_own_settings = is_own_settings?
    @can_enable_slack_status = @user.slack_access_token.present? && @user.slack_scopes.include?("users.profile:write")

    @enabled_sailors_logs = SailorsLogNotificationPreference.where(
      slack_uid: @user.slack_uid,
      enabled: true,
    ).where.not(slack_channel_id: SailorsLog::DEFAULT_CHANNELS)

    @heartbeats_migration_jobs = @user.data_migration_jobs

    @projects = @user.project_repo_mappings.distinct.pluck(:project_name)
    heartbeat_language_and_projects = @user.heartbeats.distinct.pluck(:language, :project)
    goal_languages = []
    goal_projects = @projects.dup

    heartbeat_language_and_projects.each do |language, project|
      categorized_language = language&.categorize_language
      goal_languages << categorized_language if categorized_language.present?
      goal_projects << project if project.present?
    end

    @goal_selectable_languages = goal_languages.uniq.sort
    @goal_selectable_projects = goal_projects.uniq.sort
    @work_time_stats_base_url = @user.slack_uid.present? ? "https://hackatime-badge.hackclub.com/#{@user.slack_uid}/" : nil
    @work_time_stats_url = if @work_time_stats_base_url.present?
      "#{@work_time_stats_base_url}#{@projects.first || 'example'}"
    end

    @general_badge_url = GithubReadmeStats.new(@user.id, "darcula").generate_badge_url
    @latest_api_key_token = @user.api_keys.last&.token
    @mirrors = current_user.wakatime_mirrors.order(created_at: :desc)
    @import_source = current_user.heartbeat_import_source
  end

  def settings_page_props(active_section:, settings_update_path:)
    heartbeats_last_7_days = @user.heartbeats.where("time >= ?", 7.days.ago.to_f).count
    channel_ids = @enabled_sailors_logs.pluck(:slack_channel_id)
    heartbeat_import_id = nil
    heartbeat_import_status = nil

    if active_section.to_s == "data" && Rails.env.development?
      heartbeat_import_id = params[:heartbeat_import_id].presence
      heartbeat_import_status = HeartbeatImportRunner.status(user: @user, import_id: heartbeat_import_id) if heartbeat_import_id
    end

    {
      active_section: active_section,
      section_paths: {
        profile: my_settings_profile_path,
        integrations: my_settings_integrations_path,
        access: my_settings_access_path,
        goals: my_settings_goals_path,
        badges: my_settings_badges_path,
        data: my_settings_data_path,
        admin: my_settings_admin_path
      },
      page_title: (@is_own_settings ? "My Settings" : "Settings | #{@user.display_name}"),
      heading: (@is_own_settings ? "Settings" : "Settings for #{@user.display_name}"),
      subheading: "Manage your profile, integrations, access, goals, and data tools.",
      settings_update_path: settings_update_path,
      create_goal_path: my_settings_goals_create_path,
      username_max_length: User::USERNAME_MAX_LENGTH,
      user: {
        id: @user.id,
        display_name: @user.display_name,
        timezone: @user.timezone,
        country_code: @user.country_code,
        username: @user.username,
        theme: @user.theme,
        uses_slack_status: @user.uses_slack_status,
        hackatime_extension_text_type: @user.hackatime_extension_text_type,
        allow_public_stats_lookup: @user.allow_public_stats_lookup,
        trust_level: @user.trust_level,
        can_request_deletion: @user.can_request_deletion?,
        github_uid: @user.github_uid,
        github_username: @user.github_username,
        slack_uid: @user.slack_uid,
        programming_goals: @user.goals.order(:created_at).map { |goal|
          goal.as_programming_goal_payload.merge(
            update_path: my_settings_goal_update_path(goal),
            destroy_path: my_settings_goal_destroy_path(goal)
          )
        }
      },
      paths: {
        settings_path: settings_update_path,
        wakatime_setup_path: my_wakatime_setup_path,
        slack_auth_path: slack_auth_path,
        github_auth_path: github_auth_path,
        github_unlink_path: github_unlink_path,
        add_email_path: add_email_auth_path,
        unlink_email_path: unlink_email_auth_path,
        rotate_api_key_path: my_settings_rotate_api_key_path,
        migrate_heartbeats_path: my_settings_migrate_heartbeats_path,
        export_all_heartbeats_path: export_my_heartbeats_path(all_data: "true"),
        export_range_heartbeats_path: export_my_heartbeats_path,
        create_heartbeat_import_path: my_heartbeat_imports_path,
        create_deletion_path: create_deletion_path,
        user_wakatime_mirrors_path: user_wakatime_mirrors_path(current_user),
        heartbeat_import_source_path: my_heartbeat_import_source_path,
        heartbeat_import_source_sync_path: sync_my_heartbeat_import_source_path
      },
      options: {
        countries: ISO3166::Country.all.map { |country|
          {
            label: country.common_name,
            value: country.alpha2
          }
        }.sort_by { |country| country[:label] },
        timezones: TZInfo::Timezone.all_identifiers.sort.map { |timezone|
          { label: timezone, value: timezone }
        },
        extension_text_types: User.hackatime_extension_text_types.keys.map { |key|
          {
            label: key.humanize,
            value: key
          }
        },
        themes: User.theme_options,
        badge_themes: GithubReadmeStats.themes,
        goals: {
          periods: Goal::PERIODS.map { |period|
            {
              label: period.humanize,
              value: period
            }
          },
          preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
          selectable_languages: @goal_selectable_languages
            .map { |language| { label: language, value: language } },
          selectable_projects: @goal_selectable_projects
            .map { |project| { label: project, value: project } }
        }
      },
      slack: {
        can_enable_status: @can_enable_slack_status,
        notification_channels: channel_ids.map { |channel_id|
          {
            id: channel_id,
            label: "##{channel_id}",
            url: "https://hackclub.slack.com/archives/#{channel_id}"
          }
        }
      },
      github: {
        connected: @user.github_uid.present?,
        username: @user.github_username,
        profile_url: (@user.github_username.present? ? "https://github.com/#{@user.github_username}" : nil)
      },
      emails: @user.email_addresses.map { |email|
        {
          email: email.email,
          source: email.source&.humanize || "Unknown",
          can_unlink: @user.can_delete_email_address?(email)
        }
      },
      badges: {
        general_badge_url: @general_badge_url,
        project_badge_url: @work_time_stats_url,
        project_badge_base_url: @work_time_stats_base_url,
        projects: @projects,
        profile_url: (@user.username.present? ? "https://hackati.me/#{@user.username}" : nil),
        markscribe_template: '{{ wakatimeDoubleCategoryBar "Languages:" wakatimeData.Languages "Projects:" wakatimeData.Projects 5 }}',
        markscribe_reference_url: "https://github.com/taciturnaxolotl/markscribe#your-wakatime-languages-formated-as-a-bar",
        markscribe_preview_image_url: "https://cdn.fluff.pw/slackcdn/524e293aa09bc5f9115c0c29c18fb4bc.png",
        heatmap_badge_url: "https://heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
        heatmap_config_url: "https://hackatime-heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}"
      },
      config_file: {
        content: generated_wakatime_config(@latest_api_key_token),
        has_api_key: @latest_api_key_token.present?,
        empty_message: "No API key is available yet. Migrate heartbeats or rotate your API key to generate one.",
        api_key: @latest_api_key_token,
        api_url: "https://#{request.host_with_port}/api/hackatime/v1"
      },
      migration: {
        enabled: Flipper.enabled?(:hackatime_v1_import),
        jobs: @heartbeats_migration_jobs.map { |job|
          {
            id: job.id,
            status: job.status
          }
        }
      },
      data_export: {
        total_heartbeats: number_with_delimiter(@user.heartbeats.count),
        total_coding_time: @user.heartbeats.duration_simple,
        heartbeats_last_7_days: number_with_delimiter(heartbeats_last_7_days),
        is_restricted: (@user.trust_level == "red")
      },
      import_source: serialized_import_source(@import_source),
      mirrors: serialized_mirrors(@mirrors),
      admin_tools: {
        visible: current_user.admin_level.in?(%w[admin superadmin]),
        mirrors: serialized_mirrors(@mirrors)
      },
      ui: {
        show_dev_import: Rails.env.development?
      },
      heartbeat_import: {
        import_id: heartbeat_import_id,
        status: heartbeat_import_status
      },
      errors: {
        full_messages: @user.errors.full_messages,
        username: @user.errors[:username]
      }
    }
  end

  def generated_wakatime_config(api_key)
    return nil if api_key.blank?

    <<~CFG
      # put this in your ~/.wakatime.cfg file

      [settings]
      api_url = https://#{request.host_with_port}/api/hackatime/v1
      api_key = #{api_key}
      heartbeat_rate_limit_seconds = 30

      # any other wakatime configs you want to add: https://github.com/wakatime/wakatime-cli/blob/develop/USAGE.md#ini-config-file
    CFG
  end

  def set_user
    @user = if params["id"].present? && params["id"] != "my"
      User.find(params["id"])
    else
      current_user
    end

    redirect_to root_path, alert: "You need to log in!" if @user.nil?
  end

  def require_current_user
    unless @user == current_user
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def is_own_settings?
    params["id"] == "my" || params["id"]&.blank?
  end

  def serialized_import_source(source)
    return nil unless source

    {
      id: source.id,
      provider: source.provider,
      endpoint_url: source.endpoint_url,
      sync_enabled: source.sync_enabled,
      status: source.status,
      initial_backfill_start_date: source.initial_backfill_start_date&.iso8601,
      initial_backfill_end_date: source.initial_backfill_end_date&.iso8601,
      backfill_cursor_date: source.backfill_cursor_date&.iso8601,
      last_synced_at: source.last_synced_at&.iso8601,
      last_synced_ago: (source.last_synced_at ? "#{time_ago_in_words(source.last_synced_at)} ago" : "Never"),
      last_error_message: source.last_error_message,
      last_error_at: source.last_error_at&.iso8601,
      consecutive_failures: source.consecutive_failures,
      imported_count: source.user.heartbeats.where(source_type: :wakapi_import).count
    }
  end

  def serialized_mirrors(mirrors)
    mirrors.map { |mirror|
      {
        id: mirror.id,
        endpoint_url: mirror.endpoint_url,
        enabled: mirror.enabled,
        last_synced_at: mirror.last_synced_at&.iso8601,
        last_synced_ago: (mirror.last_synced_at ? "#{time_ago_in_words(mirror.last_synced_at)} ago" : "Never"),
        consecutive_failures: mirror.consecutive_failures,
        last_error_message: mirror.last_error_message,
        last_error_at: mirror.last_error_at&.iso8601,
        destroy_path: user_wakatime_mirror_path(current_user, mirror)
      }
    }
  end
end
