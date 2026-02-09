# frozen_string_literal: true

class InertiaController < ApplicationController
  inertia_share layout: -> { inertia_layout_props }

  private

  def inertia_layout_props
    {
      nav: inertia_nav_props,
      footer: inertia_footer_props,
      currently_hacking: currently_hacking_props,
      csrf_token: form_authenticity_token,
      signout_path: signout_path,
      show_stop_impersonating: session[:impersonater_user_id].present?,
      stop_impersonating_path: stop_impersonating_path
    }
  end

  def inertia_nav_props
    {
      flash: inertia_flash_messages,
      user_present: current_user.present?,
      user_mention_html: current_user ? render_to_string(partial: "shared/user_mention", locals: { user: current_user }) : nil,
      streak_html: current_user ? render_to_string(partial: "static_pages/streak", locals: { user: current_user, show_text: true, turbo_frame: false }) : nil,
      admin_level_html: current_user ? render_to_string(partial: "static_pages/admin_level", locals: { user: current_user }) : nil,
      login_path: slack_auth_path,
      links: inertia_primary_links,
      dev_links: inertia_dev_links,
      admin_links: inertia_admin_links,
      viewer_links: inertia_viewer_links,
      superadmin_links: inertia_superadmin_links,
      activities_html: inertia_activities_html
    }
  end

  def inertia_flash_messages
    flash.to_hash.map do |type, message|
      {
        message: message.to_s,
        class_name: flash_class_for(type)
      }
    end
  end

  def flash_class_for(type)
    case type.to_sym
    when :notice, :success
      "flash-message--success"
    else
      "flash-message--error"
    end
  end

  def inertia_primary_links
    links = []
    links << inertia_link("Home", root_path, active: helpers.current_page?(root_path))
    links << inertia_link("Leaderboards", leaderboards_path, active: helpers.current_page?(leaderboards_path))

    if current_user
      links << inertia_link("Projects", my_projects_path, active: helpers.current_page?(my_projects_path))
      links << inertia_link("Docs", docs_path, active: helpers.current_page?(docs_path) || request.path.start_with?("/docs"))
      links << inertia_link("Extensions", extensions_path, active: helpers.current_page?(extensions_path))
      links << inertia_link("Settings", my_settings_path, active: helpers.current_page?(my_settings_path))
      links << inertia_link("My OAuth Apps", oauth_applications_path, active: helpers.current_page?(oauth_applications_path) || request.path.start_with?("/oauth/applications"))
      links << { label: "Logout", action: "logout" }
    else
      links << inertia_link("Docs", docs_path, active: helpers.current_page?(docs_path) || request.path.start_with?("/docs"))
      links << inertia_link("Extensions", extensions_path, active: helpers.current_page?(extensions_path))
      links << inertia_link("What is Hackatime?", "/what-is-hackatime", active: helpers.current_page?("/what-is-hackatime"))
    end

    links
  end

  def inertia_dev_links
    return [] unless Rails.env.development?

    [
      inertia_link("Letter Opener", letter_opener_web_path, active: helpers.current_page?(letter_opener_web_path)),
      inertia_link("Mailers", "/rails/mailers", active: helpers.current_page?("/rails/mailers"))
    ]
  end

  def inertia_admin_links
    return [] unless current_user&.admin_level.in?(%w[admin superadmin])

    links = []
    links << inertia_link("Review Timeline", admin_timeline_path, active: helpers.current_page?(admin_timeline_path))
    links << inertia_link("Trust Level Logs", admin_trust_level_audit_logs_path, active: helpers.current_page?(admin_trust_level_audit_logs_path) || request.path.start_with?("/admin/trust_level_audit_logs"))
    links << inertia_link("Admin API Keys", admin_admin_api_keys_path, active: helpers.current_page?(admin_admin_api_keys_path) || request.path.start_with?("/admin/admin_api_keys"))
    links
  end

  def inertia_viewer_links
    return [] unless current_user&.admin_level == "viewer"

    [
      inertia_link("Review Timeline", admin_timeline_path, active: helpers.current_page?(admin_timeline_path)),
      inertia_link("Trust Level Logs", admin_trust_level_audit_logs_path, active: helpers.current_page?(admin_trust_level_audit_logs_path) || request.path.start_with?("/admin/trust_level_audit_logs")),
      inertia_link("Admin API Keys", admin_admin_api_keys_path, active: helpers.current_page?(admin_admin_api_keys_path) || request.path.start_with?("/admin/admin_api_keys"))
    ]
  end

  def inertia_superadmin_links
    return [] unless current_user&.admin_level == "superadmin"

    links = []
    links << inertia_link("Admin Management", admin_admin_users_path, active: helpers.current_page?(admin_admin_users_path))
    pending_count = DeletionRequest.pending.count
    links << inertia_link("Account Deletions", admin_deletion_requests_path, active: helpers.current_page?(admin_deletion_requests_path), badge: pending_count.positive? ? pending_count : nil)
    links << inertia_link("GoodBoy", good_job_path, active: helpers.current_page?(good_job_path))
    links << inertia_link("All OAuth Apps", admin_oauth_applications_path, active: helpers.current_page?(admin_oauth_applications_path) || request.path.start_with?("/admin/oauth_applications"))
    links << inertia_link("Feature Flags", flipper_path, active: helpers.current_page?(flipper_path))
    links
  end

  def inertia_link(label, href, active: false, badge: nil)
    { label: label, href: href, active: active, badge: badge }
  end

  def inertia_activities_html
    return nil unless defined?(@activities) && @activities.present?
    helpers.render_activities(@activities)
  end

  def inertia_footer_props
    helpers = ApplicationController.helpers
    cache = helpers.cache_stats
    hours = active_users_graph_data.map.with_index do |entry, index|
      {
        height: entry[:height],
        title: "#{helpers.pluralize(index + 1, 'hour')} ago, #{helpers.pluralize(entry[:users], 'people')} logged time. '#{FlavorText.latin_phrases.sample}.'"
      }
    end

    {
      git_version: Rails.application.config.git_version,
      commit_link: Rails.application.config.commit_link,
      server_start_time_ago: helpers.time_ago_in_words(Rails.application.config.server_start_time),
      heartbeat_recent_count: Heartbeat.recent_count,
      heartbeat_recent_imported_count: Heartbeat.recent_imported_count,
      query_count: QueryCount::Counter.counter,
      query_cache_count: QueryCount::Counter.counter_cache,
      cache_hits: cache[:hits],
      cache_misses: cache[:misses],
      requests_per_second: helpers.requests_per_second,
      active_users_graph: hours
    }
  end

  def currently_hacking_props
    data = Cache::CurrentlyHackingJob.perform_now
    users = (data[:users] || []).map do |u|
      proj = data[:active_projects]&.dig(u.id)
      {
        id: u.id,
        display_name: u.display_name,
        slack_uid: u.slack_uid,
        avatar_url: u.avatar_url,
        active_project: proj && { name: proj.project_name, repo_url: proj.repo_url }
      }
    end
    {
      count: users.size,
      users: users,
      interval: 30_000
    }
  end
end
