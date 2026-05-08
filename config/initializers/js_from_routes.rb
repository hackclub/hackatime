# frozen_string_literal: true

# Generates path helpers from Rails routes for the Inertia/Svelte frontend.
# See https://js-from-routes.netlify.app for documentation.
#
# We export a curated allowlist of routes (by route name) rather than the
# whole routes table, so the generated `app/javascript/api/` directory stays
# small and stable. To export a new route from JS, add its `as:` name to
# `EXPORTED_ROUTES` below, then refresh the page (or run
# `bin/rake js_from_routes:generate` in development).
return unless defined?(JsFromRoutes)

module JsFromRoutes
  # Whitelist of route names (matching Rails' `as:` / route helper names) that
  # should be exposed to the JS frontend. We use names instead of marking each
  # route in `config/routes.rb` to keep route definitions clean and avoid
  # accidentally exposing internal API routes.
  EXPORTED_ROUTES = %w[
    root

    rotate_secret_oauth_application
    oauth_applications
    oauth_application
    new_oauth_application
    edit_oauth_application
    oauth_authorization
    toggle_verified_admin_oauth_application

    signin
    signout
    hca_auth
    slack_auth
    github_auth
    github_unlink
    email_auth
    add_email_auth
    unlink_email_auth
    stop_impersonating

    leaderboards

    docs
    doc

    settings_user
    my_settings
    my_settings_profile
    my_settings_profile_region
    my_settings_profile_username
    my_settings_setup
    my_settings_appearance
    my_settings_appearance_theme
    my_settings_editors
    my_settings_editors_update
    my_settings_slack_github
    my_settings_slack_github_update
    my_settings_notifications
    my_settings_notifications_update
    my_settings_privacy
    my_settings_privacy_update
    my_settings_rotate_api_key
    my_settings_goals
    my_settings_goals_create
    my_settings_goal_update
    my_settings_goal_destroy
    my_settings_badges
    my_settings_imports_exports

    my_projects
    my_project
    edit_my_project_repo_mapping
    my_project_repo_mapping
    archive_my_project_repo_mapping
    unarchive_my_project_repo_mapping
    toggle_share_my_project_repo_mapping

    my_heartbeat_imports
    wakatime_download_link_my_heartbeat_imports
    export_my_heartbeats

    deletion
    create_deletion

    my_wakatime_setup
    my_wakatime_setup_step_2
    my_wakatime_setup_step_3
    my_wakatime_setup_step_4

    profile
    profile_project

    extensions

    admin_timeline
    admin_trust_level_audit_logs
    admin_admin_api_keys
    admin_admin_users
    admin_deletion_requests
    admin_oauth_applications
    admin_account_merger
    search_users_admin_account_merger
    merge_admin_account_merger

    good_job
    flipper

    api_v1_my_heartbeats_most_recent
  ].to_set.freeze
end

JsFromRoutes.config do |config|
  # Emit TypeScript files into `app/javascript/api/`.
  config.file_suffix = "Api.ts"

  # A controller is "exported" if at least one of its routes is in
  # `EXPORTED_ROUTES`. Once a controller is exported we also export its
  # nameless siblings (e.g. Doorkeeper's anonymous `create`/`update`/`destroy`
  # that share a URL with a named GET route) so the full RESTful API is
  # available in JS.
  config.export_if = ->(route) {
    next false unless route.verb.present?
    next true if route.name && JsFromRoutes::EXPORTED_ROUTES.include?(route.name)
    next false if route.name # named, but not in the allowlist

    controller = route.requirements[:controller]
    next false unless controller

    Rails.application.routes.routes.any? { |r|
      r.name &&
        JsFromRoutes::EXPORTED_ROUTES.include?(r.name) &&
        r.requirements[:controller] == controller
    }
  }
end
