# frozen_string_literal: true

class InertiaController < ApplicationController
  inertia_share layout: -> { inertia_layout_props }

  private

  def inertia_layout_props
    {
      nav: inertia_nav_props,
      footer: inertia_footer_props,
      theme: inertia_theme_props,
      csrf_token: form_authenticity_token,
      hide_sidebar: false,
      hide_footer: false,
      full_width: false,
      show_stop_impersonating: session[:impersonater_user_id].present?
    }
  end

  def inertia_theme_props
    {
      name: helpers.current_theme,
      color_scheme: helpers.current_theme_color_scheme,
      theme_color: helpers.current_theme_color
    }
  end

  def inertia_nav_props
    {
      flash: inertia_flash_messages,
      user_present: current_user.present?,
      current_user: inertia_nav_current_user,
      links: inertia_primary_links,
      dev_links: inertia_dev_links,
      admin_links: inertia_admin_links,
      viewer_links: inertia_viewer_links,
      superadmin_links: inertia_superadmin_links,
      ultraadmin_links: inertia_ultraadmin_links
    }
  end

  def inertia_flash_messages
    flash.to_hash.filter_map do |type, message|
      next unless %w[notice success alert error].include?(type.to_s)
      { message: message.to_s, class_name: flash_class_for(type) }
    end
  end

  def flash_class_for(type)
    %i[notice success].include?(type.to_sym) ? "flash-message--success" : "flash-message--error"
  end

  def inertia_primary_links
    links = [
      inertia_link("Home", root_path, active: helpers.current_page?(root_path)),
      inertia_link("Leaderboards", leaderboards_path, active: helpers.current_page?(leaderboards_path))
    ]

    if current_user
      links += [
        inertia_link("Projects", my_projects_path, active: request.path.start_with?("/my/projects")),
        inertia_link("Docs", "/docs", active: request.path.start_with?("/docs"), inertia: false),
        inertia_link("Extensions", extensions_path, active: helpers.current_page?(extensions_path)),
        inertia_link("Settings", my_settings_path, active: request.path.start_with?("/my/settings")),
        inertia_link("My OAuth Apps", oauth_applications_path, active: helpers.current_page?(oauth_applications_path) || request.path.start_with?("/oauth/applications")),
        { label: "Logout", action: "logout" }
      ]
    else
      links += [
        inertia_link("Docs", "/docs", active: request.path.start_with?("/docs"), inertia: false),
        inertia_link("Extensions", extensions_path, active: helpers.current_page?(extensions_path))
      ]
    end

    links
  end

  def inertia_dev_links
    return [] unless Rails.env.development?
    [
      inertia_link("Letter Opener", letter_opener_web_path, active: helpers.current_page?(letter_opener_web_path), inertia: false),
      inertia_link("Mailers", "/rails/mailers", active: helpers.current_page?("/rails/mailers"), inertia: false)
    ]
  end

  ADMIN_NAV_LINKS = [
    [ :admin_timeline_path, "Review Timeline" ],
    [ :admin_trust_level_audit_logs_path, "Trust Level Logs", "/admin/trust_level_audit_logs" ],
    [ :admin_admin_api_keys_path, "Admin API Keys", "/admin/admin_api_keys" ],
    [ :admin_leaderboard_shadowbans_path, "Leaderboard Shadowbans", "/admin/leaderboard_shadowbans" ]
  ].freeze

  def inertia_admin_links
    return [] unless current_user&.admin_level.in?(%w[admin superadmin ultraadmin])

    links = build_nav_from(ADMIN_NAV_LINKS)
    links
  end

  def inertia_viewer_links
    return [] unless current_user&.admin_level == "viewer"
    build_nav_from(ADMIN_NAV_LINKS)
  end

  def inertia_superadmin_links
    return [] unless current_user&.admin_level.in?(%w[superadmin ultraadmin])

    pending_count = DeletionRequest.pending.count
    [
      inertia_link("Admin Management", admin_admin_users_path, active: helpers.current_page?(admin_admin_users_path)),
      inertia_link("Account Deletions", admin_deletion_requests_path, active: helpers.current_page?(admin_deletion_requests_path), badge: pending_count.positive? ? pending_count : nil),
      inertia_link("All OAuth Apps", admin_oauth_applications_path, active: helpers.current_page?(admin_oauth_applications_path) || request.path.start_with?("/admin/oauth_applications"))
    ]
  end

  def inertia_ultraadmin_links
    return [] unless current_user&.admin_level == "ultraadmin"
    [
      inertia_link("GoodBoy", good_job_path, active: helpers.current_page?(good_job_path), inertia: false),
      inertia_link("Feature Flags", flipper_path, active: helpers.current_page?(flipper_path), inertia: false),
      inertia_link("Account Merger", admin_account_merger_path, active: helpers.current_page?(admin_account_merger_path) || request.path.start_with?("/admin/account_merger"))
    ]
  end

  def build_nav_from(entries)
    entries.map do |path_method, label, prefix|
      href = send(path_method)
      inertia_link(label, href, active: helpers.current_page?(href) || (prefix && request.path.start_with?(prefix)))
    end
  end

  def inertia_link(label, href, active: false, badge: nil, inertia: true, tool: nil)
    { label: label, href: href, active: active, badge: badge, inertia: inertia, tool: tool }
  end

  def inertia_nav_current_user
    return nil unless current_user
    country = current_user.country_code.present? ? ISO3166::Country.new(current_user.country_code) : nil
    {
      display_name: current_user.display_name,
      avatar_url: current_user.avatar_url,
      title: FlavorText.same_user.sample,
      country_code: current_user.country_code,
      country_name: country&.common_name,
      streak_days: current_user.streak_days,
      admin_level: current_user.admin_level
    }
  end

  def inertia_footer_props
    h = ApplicationController.helpers
    hours = active_users_graph_data.map { |entry| { height: entry[:height], users: entry[:users] } }

    props = {
      git_version: Rails.application.config.git_version,
      commit_link: Rails.application.config.commit_link,
      server_start_time_ago: h.time_ago_in_words(Rails.application.config.server_start_time),
      heartbeat_recent_count: Heartbeat.recent_count,
      heartbeat_recent_imported_count: Heartbeat.recent_imported_count,
      active_users_graph: hours
    }

    props[:query_stats] = {
      count: QueryCount::Counter.counter,
      cache_count: QueryCount::Counter.counter_cache
    } if current_user&.can_view_query_stats?

    props
  end
end
