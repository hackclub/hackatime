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

  def self.timezone_options
    @timezone_options ||= ActiveSupport::TimeZone.all
      .group_by { |z| z.tzinfo.identifier } # London & Edinburgh both map to Europe/London
      .map { |identifier, zones| { label: "(GMT#{zones.first.formatted_offset}) #{zones.map(&:name).join(", ")}", value: identifier } }
      .freeze
  end

  def set_user
    @user = current_user
    redirect_to root_path, alert: "You need to log in!" if @user.nil?
  end
end
