class Settings::BaseController < InertiaController
  layout "inertia"

  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user

  private

  def render_settings_page(active_section:, status: :ok, extra_props: {})
    render inertia: settings_component_for(active_section), props: common_props(
      active_section: active_section
    ).merge(section_props).merge(extra_props), status: status
  end

  def settings_component_for(active_section)
    {
      "profile" => "Users/Settings/Profile",
      "setup" => "Users/Settings/Setup",
      "appearance" => "Users/Settings/Appearance",
      "editors" => "Users/Settings/Editors",
      "slack_github" => "Users/Settings/SlackGithub",
      "notifications" => "Users/Settings/Notifications",
      "privacy" => "Users/Settings/Privacy",
      "goals" => "Users/Settings/Goals",
      "badges" => "Users/Settings/Badges",
      "imports_exports" => "Users/Settings/ImportsExports"
    }.fetch(active_section.to_s, "Users/Settings/Profile")
  end

  # Lightweight props shared by every settings page
  def common_props(active_section:)
    is_own = is_own_settings?

    {
      active_section: active_section,
      section_paths: {
        profile: my_settings_profile_path,
        setup: my_settings_setup_path,
        appearance: my_settings_appearance_path,
        editors: my_settings_editors_path,
        slack_github: my_settings_slack_github_path,
        notifications: my_settings_notifications_path,
        privacy: my_settings_privacy_path,
        goals: my_settings_goals_path,
        badges: my_settings_badges_path,
        imports_exports: my_settings_imports_exports_path
      },
      page_title: (is_own ? "My Settings" : "Settings | #{@user.display_name}"),
      heading: (is_own ? "Settings" : "Settings for #{@user.display_name}"),
      subheading: "Manage your profile, appearance, editors, integrations, privacy, goals, and data tools.",

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

  USER_PROP_BUILDERS = {
    id: ->(u) { u.id },
    display_name: ->(u) { u.display_name },
    timezone: ->(u) { u.timezone },
    country_code: ->(u) { u.country_code },
    username: ->(u) { u.username },
    theme: ->(u) { u.theme },
    uses_slack_status: ->(u) { u.uses_slack_status },
    weekly_summary_email_enabled: ->(u) { u.subscribed?("weekly_summary") },
    hackatime_extension_text_type: ->(u) { u.hackatime_extension_text_type },
    show_goals_in_statusbar: ->(u) { u.show_goals_in_statusbar },
    allow_public_stats_lookup: ->(u) { u.allow_public_stats_lookup },
    trust_level: ->(u) { u.trust_level },
    can_request_deletion: ->(u) { u.can_request_deletion? },
    github_uid: ->(u) { u.github_uid },
    github_username: ->(u) { u.github_username },
    slack_uid: ->(u) { u.slack_uid }
  }.freeze

  # Build a user prop hash containing only the requested keys.
  def user_props(keys: nil)
    selected = keys.present? ? USER_PROP_BUILDERS.slice(*keys) : USER_PROP_BUILDERS
    selected.transform_values { |builder| builder.call(@user) }
  end

  def programming_goals_props
    @user.goals.order(:created_at).map { |goal|
      goal.as_programming_goal_payload.merge(
        update_path: my_settings_goal_update_path(goal),
        destroy_path: my_settings_goal_destroy_path(goal)
      )
    }
  end

  PATH_BUILDERS = {
    settings_path: -> { my_settings_profile_path },
    wakatime_setup_path: -> { my_wakatime_setup_path },
    slack_auth_path: -> { slack_auth_path },
    github_auth_path: -> { github_auth_path },
    github_unlink_path: -> { github_unlink_path },
    add_email_path: -> { add_email_auth_path },
    unlink_email_path: -> { unlink_email_auth_path },
    rotate_api_key_path: -> { my_settings_rotate_api_key_path },
    export_all_heartbeats_path: -> { export_my_heartbeats_path(all_data: "true") },
    export_range_heartbeats_path: -> { export_my_heartbeats_path },
    create_heartbeat_import_path: -> { my_heartbeat_imports_path },
    create_deletion_path: -> { create_deletion_path }
  }.freeze

  # Build a paths hash containing only the requested keys.
  # Pass `keys:` to limit to a subset; defaults to all paths for backwards compatibility.
  def paths_props(keys: nil)
    selected = keys.present? ? PATH_BUILDERS.slice(*keys) : PATH_BUILDERS
    selected.transform_values { |builder| instance_exec(&builder) }
  end

  def project_list
    @project_list ||= @user.project_repo_mappings.includes(:repository).distinct.map do |mapping|
      repo_path = mapping.repository&.full_path || mapping.project_name
      { display_name: mapping.project_name, repo_path: repo_path }
    end
  end

  def options_props
    base_options.merge(goals: goal_options)
  end

  BASE_OPTION_BUILDERS = {
    countries: -> {
      ISO3166::Country.all.map { |country|
        { label: country.common_name, value: country.alpha2 }
      }.sort_by { |country| country[:label] }
    },
    timezones: -> {
      TZInfo::Timezone.all_identifiers.sort.map { |timezone|
        { label: timezone, value: timezone }
      }
    },
    extension_text_types: -> {
      User.hackatime_extension_text_types.keys.map { |key|
        { label: key.humanize, value: key }
      }
    },
    themes: -> { User.theme_options },
    badge_themes: -> { GithubReadmeStats.themes }
  }.freeze

  # Build a base options hash containing only the requested keys.
  # Pass `keys:` to limit to a subset; defaults to all options for backwards compatibility.
  def base_options(keys: nil)
    selected = keys.present? ? BASE_OPTION_BUILDERS.slice(*keys) : BASE_OPTION_BUILDERS
    selected.transform_values { |builder| builder.call }
  end

  def goal_options
    heartbeat_language_and_projects = @user.heartbeats.distinct.pluck(:language, :project)
    goal_languages = []
    goal_projects = project_list.map { |p| p[:display_name] }

    heartbeat_language_and_projects.each do |language, project|
      categorized_language = language&.categorize_language
      goal_languages << categorized_language if categorized_language.present?
      goal_projects << project if project.present?
    end

    {
      periods: Goal::PERIODS.map { |period|
        { label: period.humanize, value: period }
      },
      preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
      selectable_languages: goal_languages.uniq.sort
        .map { |language| { label: language, value: language } },
      selectable_projects: goal_projects.uniq.sort
        .map { |project| { label: project, value: project } }
    }
  end

  def badges_props
    work_time_stats_base_url = "#{request.base_url}/api/v1/badge/#{badge_user_id}/"
    work_time_stats_url = if work_time_stats_base_url.present? && project_list.first.present?
      "#{work_time_stats_base_url}#{project_list.first[:repo_path]}"
    end

    {
      general_badge_url: GithubReadmeStats.new(@user.id, "darcula").generate_badge_url,
      project_badge_url: work_time_stats_url,
      project_badge_base_url: work_time_stats_base_url,
      projects: project_list,
      markscribe_template: '{{ wakatimeDoubleCategoryBar "Languages:" wakatimeData.Languages "Projects:" wakatimeData.Projects 5 }}',
      markscribe_reference_url: "https://github.com/taciturnaxolotl/markscribe#your-wakatime-languages-formated-as-a-bar",
      markscribe_preview_image_url: "https://cdn.fluff.pw/slackcdn/524e293aa09bc5f9115c0c29c18fb4bc.png",
      heatmap_badge_url: "https://heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      heatmap_config_url: "https://hackatime-heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      hackabox_repo_url: "https://github.com/quackclub/hacka-box",
      hackabox_preview_image_url: "https://user-cdn.hackclub-assets.com/019cef81-366a-7543-ad7c-21b738310f23/image.png"
    }
  end

  def badge_user_id
    @user.slack_uid.presence || @user.username.presence || @user.id.to_s
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
