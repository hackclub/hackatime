source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use PostgreSQL as the database for Wakatime
gem "pg"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# PaperTrail for auditing
gem "paper_trail"
# Handle CORS (Cross-Origin Resource Sharing)
gem "rack-cors"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_cable"

# Profiling & error tracking
gem "stackprof"
gem "sentry-ruby"
gem "sentry-rails"
# Trying out sentry alternative
gem "honeybadger"

gem "good_job"

# Slack client
gem "slack-ruby-client"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# For query count tracking
gem "query_count"

# Rate limiting
gem "rack-attack"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use dotenv for environment variables
gem "dotenv-rails"

# Authentication
# gem "oauth2"

# Added from the code block
gem "http"

gem "public_activity"

# Bulk import
gem "activerecord-import"

# Rack Mini Profiler [https://github.com/MiniProfiler/rack-mini-profiler]
gem "rack-mini-profiler"
# For memory profiling via RMP
gem "memory_profiler"
gem "flamegraph"

gem "skylight"

# Ahoy analytics
gem "ahoy_matey"
gem "geocoder"
gem "ahoy_captain", git: "https://github.com/johnmcdowall/ahoy_captain.git", branch: "fix_importmaps"

gem "pagy", "~> 43.1"

# Airtable syncing
gem "norairrecord", "~> 0.5.1"

# Country codes
gem "countries"

# Markdown parsing
gem "redcarpet"

gem "ruby_identicon"

# Feature flags
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # ERB linting [https://github.com/Shopify/erb_lint]
  gem "erb_lint", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Preview emails in the browser [https://github.com/ryanb/letter_opener]
  gem "letter_opener"
  gem "letter_opener_web", "~> 3.0"

  # Bullet [https://github.com/flyerhzm/bullet]
  gem "bullet"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

group :production do
  # fix request.remote_ip in prod [https://github.com/modosc/cloudflare-rails?tab=readme-ov-file]
  gem "cloudflare-rails"
end

gem "htmlcompressor", "~> 0.4.0"

gem "doorkeeper", "~> 5.8"

gem "autotuner", "~> 1.0"

gem "tailwindcss-ruby", "~> 4.1"

gem "tailwindcss-rails", "~> 4.2"
