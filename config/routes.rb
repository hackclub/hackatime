class AdminConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    user&.admin?
  end
end

Rails.application.routes.draw do
  constraints AdminConstraint do
    mount GoodJob::Engine => "good_job"
    mount AhoyCaptain::Engine => "/ahoy_captain"

    get "/impersonate/:id", to: "sessions#impersonate", as: :impersonate_user
  end
  get "/stop_impersonating", to: "sessions#stop_impersonating", as: :stop_impersonating

  namespace :admin do
    get "timeline", to: "timeline#show", as: :timeline
    get "timeline/search_users", to: "timeline#search_users"
    get "timeline/leaderboard_users", to: "timeline#leaderboard_users"

    get "post_reviews/:post_id", to: "post_reviews#show", as: :post_review
    patch "post_reviews/:post_id", to: "post_reviews#update"
    get "post_reviews/:post_id/date/:date", to: "post_reviews#show", as: :post_review_on_date

    get "ysws_reviews/:record_id", to: "ysws_reviews#show", as: :ysws_review
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "static_pages#index"

  resources :static_pages, only: [ :index ] do
    collection do
      get :project_durations
      get :activity_graph
      get :currently_hacking
      get :filterable_dashboard_content
      get :filterable_dashboard
      get :mini_leaderboard
      get "🃏", to: "static_pages#🃏", as: :wildcard
      get :streak
      # get :timeline # Removed: Old route for timeline
    end
  end

  # Auth routes
  get "/auth/slack", to: "sessions#new", as: :slack_auth
  get "/auth/slack/callback", to: "sessions#create"
  get "/auth/github", to: "sessions#github_new", as: :github_auth
  get "/auth/github/callback", to: "sessions#github_create"
  post "/auth/email", to: "sessions#email", as: :email_auth
  post "/auth/email/add", to: "sessions#add_email", as: :add_email_auth
  get "/auth/token/:token", to: "sessions#token", as: :auth_token
  get "/auth/close_window", to: "sessions#close_window", as: :close_window
  delete "signout", to: "sessions#destroy", as: "signout"

  resources :leaderboards, only: [ :index ]

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
    resources :project_repo_mappings, param: :project_name, only: [ :edit, :update ]
    resource :mailing_address, only: [ :show, :edit ]
    get "mailroom", to: "mailroom#index"
  end

  get "my/wakatime_setup", to: "users#wakatime_setup"
  get "my/wakatime_setup/step-2", to: "users#wakatime_setup_step_2"
  get "my/wakatime_setup/step-3", to: "users#wakatime_setup_step_3"
  get "my/wakatime_setup/step-4", to: "users#wakatime_setup_step_4"

  post "/sailors_log/slack/commands", to: "slack#create"
  post "/timedump/slack/commands", to: "slack#create"

  # API routes
  namespace :api do
    # This is our own API– don't worry about compatibility.
    namespace :v1 do
      get "stats", to: "stats#show"
      get "users/:username/stats", to: "stats#user_stats"
      get "users/:username/heartbeats/spans", to: "stats#user_spans"

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
    end

    # wakatime compatible summary
    get "summary", to: "summary#index"

    # Everything in this namespace conforms to wakatime.com's API.
    namespace :hackatime do
      namespace :v1 do
        get "/", to: "hackatime#index" # many clients seem to link this as the user's dashboard
        get "/users/:id/statusbar/today", to: "hackatime#status_bar_today"
        post "/users/:id/heartbeats", to: "hackatime#push_heartbeats"
      end
    end
  end

  resources :scrapyard_leaderboards, only: [ :index, :show ]
end
