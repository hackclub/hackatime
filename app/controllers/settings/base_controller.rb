class Settings::BaseController < InertiaController
  layout "inertia"

  before_action :set_user

  def show = render_settings_page

  private

  def render_settings_page(status: :ok, extra_props: {})
    section = controller_name
    render inertia: "Users/Settings/#{section.camelize}",
           props: common_props(active_section: section).merge(page_props).merge(extra_props),
           status: status
  end

  # Lightweight props shared by every settings page
  def common_props(active_section:)
    { active_section: active_section,
      errors: { full_messages: @user.errors.full_messages,
                display_name_override: @user.errors[:display_name_override],
                username: @user.errors[:username] } }
  end

  # Subclasses override this to provide page-specific props
  def page_props = {}

  USER_PROP_BUILDERS = {
    id: ->(u) { u.id },
    display_name: ->(u) { u.display_name },
    display_name_override: ->(u) { u.display_name_override },
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

  BASE_OPTION_BUILDERS = {
    countries: -> { ISO3166::Country.all.map { |c| { label: c.common_name, value: c.alpha2 } }.sort_by { |c| c[:label] } },
    # see .timezone_options below; a user's current zone, if outside the list,
    # is pinned in ProfileController#page_props so it never disappears.
    timezones: -> { Settings::BaseController.timezone_options },
    extension_text_types: -> { User.hackatime_extension_text_types.keys.map { |k| { label: k.humanize, value: k } } },
    themes: -> { User.theme_options }
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

  def set_user
    @user = current_user
    redirect_to root_path, alert: "You need to log in!" if @user.nil?
  end
end
