class AdminLevelConstraint
  def initialize(*require)
    @require = require.map(&:to_s)
  end

  def matches?(request)
    return false unless request.session[:user_id]
    user = User.find_by(id: request.session[:user_id])
    user && @require.include?(user.admin_level)
  end
end

Rails.application.routes.draw do
  use_doorkeeper

  root "static_pages#index"

  constraints AdminLevelConstraint.new(:superadmin) do
    mount GoodJob::Engine => "good_job"
    mount AhoyCaptain::Engine => "/ahoy_captain"
    mount Flipper::UI.app(Flipper) => "flipper", as: :flipper

    get "/my/mailing_address", to: "my/mailing_address#show", as: :my_mailing_address
  end

  constraints AdminLevelConstraint.new(:superadmin, :admin, :viewer) do
    namespace :admin do
      get "timeline", to: "timeline#show", as: :timeline
      get "timeline/search_users", to: "timeline#search_users"
      get "timeline/leaderboard_users", to: "timeline#leaderboard_users"

      get "post_reviews/:post_id", to: "post_reviews#show", as: :post_review
      patch "post_reviews/:post_id", to: "post_reviews#update"
      get "post_reviews/:post_id/date/:date", to: "post_reviews#show", as: :post_review_on_date

      get "ysws_reviews/:record_id", to: "ysws_reviews#show", as: :ysws_review

      resources :trust_level_audit_logs, only: [ :index, :show ]
      resources :admin_api_keys, except: [ :edit, :update ]
    end
    get "/impersonate/:id", to: "sessions#impersonate", as: :impersonate_user
  end
  get "/stop_impersonating", to: "sessions#stop_impersonating", as: :stop_impersonating

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :static_pages, only: [ :index ] do
    collection do
      get :project_durations
      get :activity_graph
      get :currently_hacking
      get :currently_hacking_count
      get :filterable_dashboard_content
      get :filterable_dashboard
      get :mini_leaderboard
      get :streak
      # get :timeline # Removed: Old route for timeline
    end
  end

  get "/minimal_login", to: "static_pages#minimal_login", as: :minimal_login

  # Auth routes
  get "/auth/slack", to: "sessions#new", as: :slack_auth
  get "/auth/slack/callback", to: "sessions#create"
  get "/auth/github", to: "sessions#github_new", as: :github_auth
  get "/auth/github/callback", to: "sessions#github_create"
  delete "/auth/github/unlink", to: "sessions#github_unlink", as: :github_unlink
  post "/auth/email", to: "sessions#email", as: :email_auth
  post "/auth/email/add", to: "sessions#add_email", as: :add_email_auth
  get "/auth/token/:token", to: "sessions#token", as: :auth_token
  get "/auth/close_window", to: "sessions#close_window", as: :close_window
  delete "signout", to: "sessions#destroy", as: "signout"

  resources :leaderboards, only: [ :index ]

  # Docs routes
  get "docs", to: "docs#index", as: :docs
  get "docs/*path", to: "docs#show", as: :doc

  # Nested under users for admin access
  resources :users, only: [] do
    get "settings", on: :member, to: "users#edit"
    patch "settings", on: :member, to: "users#update"
    member do
      patch :update_trust_level
    end
    resource :wakatime_mirrors, only: [ :create ]
    resources :wakatime_mirrors, only: [ :destroy ]
  end

  get "my/projects", to: "my/project_repo_mappings#index", as: :my_projects

  # Namespace for current user actions
  get "my/settings", to: "users#edit", as: :my_settings
  patch "my/settings", to: "users#update"
  post "my/settings/migrate_heartbeats", to: "users#migrate_heartbeats", as: :my_settings_migrate_heartbeats

  namespace :my do
    resources :project_repo_mappings, param: :project_name, only: [ :edit, :update ], constraints: { project_name: /.+/ }
    resource :mailing_address, only: [ :show, :edit ]
    get "mailroom", to: "mailroom#index"
    resources :heartbeats, only: [] do
      collection do
        get :export
      end
    end
  end

  get "my/wakatime_setup", to: "users#wakatime_setup"
  get "my/wakatime_setup/step-2", to: "users#wakatime_setup_step_2"
  get "my/wakatime_setup/step-3", to: "users#wakatime_setup_step_3"
  get "my/wakatime_setup/step-4", to: "users#wakatime_setup_step_4"

  post "/sailors_log/slack/commands", to: "slack#create"
  post "/timedump/slack/commands", to: "slack#create"

  get "/hackatime/v1", to: redirect("/", status: 302) # some clients seem to link this as the user's dashboard instead of /api/v1/hackatime
  # API routes
  namespace :api do
    # This is our own API– don't worry about compatibility.
    namespace :v1 do
      get "stats", to: "stats#show"
      get "users/:username/stats", to: "stats#user_stats"
      get "users/:username/heartbeats/spans", to: "stats#user_spans"
      get "users/:username/trust_factor", to: "stats#trust_factor"
      get "users/:username/projects", to: "stats#user_projects"
      get "users/:username/project/:project_name", to: "stats#user_project"
      get "users/:username/projects/details", to: "stats#user_projects_details"

      get "users/lookup_email/:email", to: "users#lookup_email", constraints: { email: /[^\/]+/ }
      get "users/lookup_slack_uid/:slack_uid", to: "users#lookup_slack_uid"

      # External service Slack OAuth integration
      post "external/slack/oauth", to: "external_slack#create_user"

      resources :ysws_programs, only: [ :index ] do
        post :claim, on: :collection
      end

      namespace :my do
        get "heartbeats/most_recent", to: "heartbeats#most_recent"
        get "heartbeats", to: "heartbeats#index"
      end

      namespace :authenticated do
        resources :me, only: [ :index ]
      end
    end

    # Admin-only API namespace
    namespace :admin do
      namespace :v1 do
        get "check", to: "admin#check"
        get "user/info", to: "admin#user_info"
        get "user/stats", to: "admin#user_stats"
        get "user/projects", to: "admin#user_projects"
        get "user/trust_logs", to: "admin#trust_logs"
        post "user/convict", to: "admin#user_convict"
        post "execute", to: "admin#execute"
      end
    end

    # wakatime compatible summary
    get "summary", to: "summary#index"

    # Everything in this namespace conforms to wakatime.com's API.
    namespace :hackatime do
      namespace :v1 do
        get "/", to: redirect("/", status: 302) # some clients seem to link this as the user's dashboard instead of /api/v1/hackatime
        get "/users/:id/statusbar/today", to: "hackatime#status_bar_today"
        post "/users/:id/heartbeats", to: "hackatime#push_heartbeats"
        get "/users/current/stats/last_7_days", to: "hackatime#stats_last_7_days"
      end
    end

    namespace :internal do
      post "/can_i_have_a_magic_link_for/:id", to: "magic_links#create"
    end
  end

  get "/sitemap.xml", to: "sitemap#sitemap", defaults: { format: "xml" }
  get "/privacy", to: "static_pages#privacy"
end
