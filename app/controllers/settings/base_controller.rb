class Settings::BaseController < InertiaController
  layout "inertia"

  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user

  private

  SETTINGS_COMPONENTS = {
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
  }.freeze

  def render_settings_page(active_section:, status: :ok, extra_props: {})
    component = SETTINGS_COMPONENTS.fetch(active_section.to_s, "Users/Settings/Profile")
    render inertia: component,
           props: common_props(active_section: active_section).merge(section_props).merge(extra_props),
           status: status
  end

  # Lightweight props shared by every settings page
  def common_props(active_section:)
    is_own = is_own_settings?
    { active_section: active_section,
      page_title: (is_own ? "My Settings" : "Settings | #{@user.display_name}"),
      heading: (is_own ? "Settings" : "Settings for #{@user.display_name}"),
      subheading: "Manage your profile, appearance, editors, integrations, privacy, goals, and data tools.",
      errors: { full_messages: @user.errors.full_messages, username: @user.errors[:username] } }
  end

  # Subclasses override this to provide section-specific props
  def section_props = {}

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
    trust_level: ->(u) { u.public_trust_level },
    can_request_deletion: ->(u) { u.can_request_deletion? },
    github_uid: ->(u) { u.github_uid },
    github_username: ->(u) { u.github_username },
    slack_uid: ->(u) { u.slack_uid }
  }.freeze

  # Build a user prop hash containing only the requested keys.
  def user_props(keys: nil)
    (keys.present? ? USER_PROP_BUILDERS.slice(*keys) : USER_PROP_BUILDERS)
      .transform_values { |builder| builder.call(@user) }
  end

  def programming_goals_props
    # Path helpers (update_path, destroy_path) are built client-side from
    # the goal id via js_from_routes — see app/javascript/api/Settings/GoalsApi.ts.
    @user.goals.order(:created_at).map(&:as_programming_goal_payload)
  end

  def project_list
    @project_list ||= @user.project_repo_mappings.includes(:repository).distinct.map do |mapping|
      { display_name: mapping.project_name,
        repo_path: mapping.repository&.full_path || mapping.project_name }
    end
  end

  def options_props = base_options.merge(goals: goal_options)

  BASE_OPTION_BUILDERS = {
    countries: -> { ISO3166::Country.all.map { |c| { label: c.common_name, value: c.alpha2 } }.sort_by { |c| c[:label] } },
    # see .timezone_options below; a user's current zone, if outside the list,
    # is pinned in ProfileController#section_props so it never disappears.
    timezones: -> { Settings::BaseController.timezone_options },
    extension_text_types: -> { User.hackatime_extension_text_types.keys.map { |k| { label: k.humanize, value: k } } },
    themes: -> { User.theme_options },
    badge_themes: -> { GithubReadmeStats.themes }
  }.freeze

  def self.timezone_options
    @timezone_options ||= ActiveSupport::TimeZone.all
      .group_by { |z| z.tzinfo.identifier } # London & Edinburgh both map to Europe/London
      .map { |identifier, zones| { label: "(GMT#{zones.first.formatted_offset}) #{zones.map(&:name).join(", ")}", value: identifier } }
      .freeze
  end

  # Build a base options hash containing only the requested keys.
  def base_options(keys: nil)
    (keys.present? ? BASE_OPTION_BUILDERS.slice(*keys) : BASE_OPTION_BUILDERS)
      .transform_values { |builder| builder.call }
  end

  def goal_options
    goal_languages = []
    goal_projects = project_list.map { |p| p[:display_name] }

    @user.heartbeats.distinct.pluck(:language, :project).each do |language, project|
      categorized = language&.categorize_language
      goal_languages << categorized if categorized.present?
      goal_projects << project if project.present?
    end

    {
      periods: Goal::PERIODS.map { |p| { label: p.humanize, value: p } },
      preset_target_seconds: Goal::PRESET_TARGET_SECONDS,
      selectable_languages: goal_languages.uniq.sort.map { |l| { label: l, value: l } },
      selectable_projects: goal_projects.uniq.sort.map { |p| { label: p, value: p } }
    }
  end

  def badges_props
    work_time_stats_base_url = "#{request.base_url}/api/v1/badge/#{badge_user_id}/"
    work_time_stats_url = (project_list.first.present? ? "#{work_time_stats_base_url}#{project_list.first[:repo_path]}" : nil)

    {
      general_badge_url: GithubReadmeStats.new(@user.id, "darcula").generate_badge_url,
      project_badge_url: work_time_stats_url,
      project_badge_base_url: work_time_stats_base_url,
      projects: project_list,
      profile_url: (@user.username.present? ? "https://hackatime.hackclub.com/@#{@user.username}" : nil),
      markscribe_template: '{{ wakatimeDoubleCategoryBar "Languages:" wakatimeData.Languages "Projects:" wakatimeData.Projects 5 }}',
      markscribe_reference_url: "https://github.com/taciturnaxolotl/markscribe#your-wakatime-languages-formated-as-a-bar",
      markscribe_preview_image_url: "https://cdn.fluff.pw/slackcdn/524e293aa09bc5f9115c0c29c18fb4bc.png",
      heatmap_badge_url: "https://heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      heatmap_config_url: "https://hackatime-heatmap.shymike.dev/?id=#{@user.id}&timezone=#{@user.timezone}",
      hackabox_repo_url: "https://github.com/quackclub/hacka-box",
      hackabox_preview_image_url: "https://user-cdn.hackclub-assets.com/019cef81-366a-7543-ad7c-21b738310f23/image.png"
    }
  end

  def badge_user_id = @user.slack_uid.presence || @user.username.presence || @user.id.to_s

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
    @user = (params["id"].present? && params["id"] != "my") ? User.find(params["id"]) : current_user
    redirect_to root_path, alert: "You need to log in!" if @user.nil?
  end

  def require_current_user
    redirect_to root_path, alert: "You are not authorized to access this page" unless @user == current_user
  end

  def is_own_settings? = params["id"] == "my" || params["id"]&.blank?
end
