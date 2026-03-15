class Settings::BaseController < InertiaController
  layout "inertia"

  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user

  private

  def render_settings_page(active_section:, settings_update_path:, status: :ok, extra_props: {})
    render inertia: settings_component_for(active_section), props: common_props(
      active_section: active_section
    ).merge(section_props).merge(extra_props), status: status
  end

  def settings_component_for(active_section)
    {
      "profile" => "Users/Settings/Profile",
      "integrations" => "Users/Settings/Integrations",
      "notifications" => "Users/Settings/Notifications",
      "access" => "Users/Settings/Access",
      "goals" => "Users/Settings/Goals",
      "badges" => "Users/Settings/Badges",
      "data" => "Users/Settings/Data"
    }.fetch(active_section.to_s, "Users/Settings/Profile")
  end

  # Lightweight props shared by every settings page
  def common_props(active_section:)
    is_own = is_own_settings?

    {
      active_section: active_section,
      section_paths: {
        profile: my_settings_profile_path,
        integrations: my_settings_integrations_path,
        notifications: my_settings_notifications_path,
        access: my_settings_access_path,
        goals: my_settings_goals_path,
        badges: my_settings_badges_path,
        data: my_settings_data_path
      },
      page_title: (is_own ? "My Settings" : "Settings | #{@user.display_name}"),
      heading: (is_own ? "Settings" : "Settings for #{@user.display_name}"),
      subheading: "Manage your profile, integrations, notifications, access, goals, and data tools.",

      errors: {
        full_messages: @user.errors.full_messages,
        username: @user.errors[:username]
      }
    }
  end

  # Subclasses override this to provide section-specific props
  def section_props
    {}
  end

  # Shared helpers used by multiple section controllers

  def user_props
    {
      id: @user.id,
      display_name: @user.display_name,
      timezone: @user.timezone,
      country_code: @user.country_code,
      username: @user.username,
      theme: @user.theme,
      uses_slack_status: @user.uses_slack_status,
      weekly_summary_email_enabled: @user.subscribed?("weekly_summary"),
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
    }
  end

  def paths_props
    {
      settings_path: my_settings_profile_path,
      wakatime_setup_path: my_wakatime_setup_path,
      slack_auth_path: slack_auth_path,
      github_auth_path: github_auth_path,
      github_unlink_path: github_unlink_path,
      add_email_path: add_email_auth_path,
      unlink_email_path: unlink_email_auth_path,
      rotate_api_key_path: my_settings_rotate_api_key_path,
      export_all_heartbeats_path: export_my_heartbeats_path(all_data: "true"),
      export_range_heartbeats_path: export_my_heartbeats_path,
      create_heartbeat_import_path: my_heartbeat_imports_path,
      create_deletion_path: create_deletion_path
    }
  end

  def options_props
    heartbeat_language_and_projects = @user.heartbeats.distinct.pluck(:language, :project)
    projects = @user.project_repo_mappings.includes(:repository).distinct.map do |mapping|
      { display_name: mapping.project_name, repo_path: mapping.repository&.full_path || mapping.project_name }
    end
    goal_languages = []
    goal_projects = projects.map { |p| p[:display_name] }

    heartbeat_language_and_projects.each do |language, project|
      categorized_language = language&.categorize_language
      goal_languages << categorized_language if categorized_language.present?
      goal_projects << project if project.present?
    end

    {
      countries: ISO3166::Country.all.map { |country|
        { label: country.common_name, value: country.alpha2 }
      }.sort_by { |country| country[:label] },
      timezones: TZInfo::Timezone.all_identifiers.sort.map { |timezone|
        { label: timezone, value: timezone }
      },
      extension_text_types: User.hackatime_extension_text_types.keys.map { |key|
        { label: key.humanize, value: key }
      },
      themes: User.theme_options,
      badge_themes: GithubReadmeStats.themes,
      goals: {
        periods: Goal::PERIODS.map { |period|
          { label: period.humanize, value: period }
        },
        preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
        selectable_languages: goal_languages.uniq.sort
          .map { |language| { label: language, value: language } },
        selectable_projects: goal_projects.uniq.sort
          .map { |project| { label: project, value: project } }
      }
    }
  end

  def badges_props
    projects = @user.project_repo_mappings.includes(:repository).distinct.map do |mapping|
      { display_name: mapping.project_name, repo_path: mapping.repository&.full_path || mapping.project_name }
    end
    work_time_stats_base_url = @user.slack_uid.present? ? "https://hackatime-badge.hackclub.com/#{@user.slack_uid}/" : nil
    work_time_stats_url = if work_time_stats_base_url.present? && projects.first.present?
      "#{work_time_stats_base_url}#{projects.first[:repo_path]}"
    end

    {
      general_badge_url: GithubReadmeStats.new(@user.id, "darcula").generate_badge_url,
      project_badge_url: work_time_stats_url,
      project_badge_base_url: work_time_stats_base_url,
      projects: projects,
      profile_url: (@user.username.present? ? "https://hackati.me/#{@user.username}" : nil),
      markscribe_template: '{{ wakatimeDoubleCategoryBar "Languages:" wakatimeData.Languages "Projects:" wakatimeData.Projects 5 }}',
      markscribe_reference_url: "https://github.com/taciturnaxolotl/markscribe#your-wakatime-languages-formated-as-a-bar",
      markscribe_preview_image_url: "https://cdn.fluff.pw/slackcdn/524e293aa09bc5f9115c0c29c18fb4bc.png",
      heatmap_badge_url: "https://heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      heatmap_config_url: "https://hackatime-heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      hackabox_repo_url: "https://github.com/quackclub/hacka-box",
      hackabox_preview_image_url: "https://user-cdn.hackclub-assets.com/019cef81-366a-7543-ad7c-21b738310f23/image.png"
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
end
