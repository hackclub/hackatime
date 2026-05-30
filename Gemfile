source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
# gem "rails", github: "rails/rails", branch: "main" # currently broken w/ bullet
gem "rails", "~> 8.1.2"
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

# Profiling & error tracking. stackprof is lazily required by
# rack-mini-profiler the first time you request ?pp=profile-gc, so we don't
# need it loaded at boot — saves ~native ext + a couple MB.
gem "stackprof", require: false
gem "sentry-ruby"
gem "sentry-rails"

gem "good_job"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# For query count tracking
gem "query_count"

# Compact request logging
gem "lograge"

# Rate limiting
gem "rack-attack"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
gem "ruby-vips", "~> 2.3", require: false

# Use dotenv for environment variables
gem "dotenv-rails"

# Authentication
# gem "oauth2"

# Added from the code block
gem "http"

# Bulk import
gem "activerecord-import"

# Fast JSON parsing
gem "oj"

# Rack Mini Profiler [https://github.com/MiniProfiler/rack-mini-profiler]
gem "rack-mini-profiler"
# For memory profiling via rack-mini-profiler — lazily required when you visit
# ?pp=profile-memory / ?pp=flamegraph, no need to load at boot.
gem "memory_profiler", require: false
gem "flamegraph", require: false
# Analytics
gem "geocoder"
gem "maxminddb"

# Country codes
gem "countries"

# Markdown parsing — only used in DocsController, so don't autoload it.
gem "redcarpet", require: false

gem "ruby_identicon"

# Feature flags
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

# Generate path helpers and API methods from Rails routes [https://js-from-routes.netlify.app]
gem "js_from_routes"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # ERB linting [https://github.com/Shopify/erb_lint]
  gem "erb_lint", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # rswag-specs provides the `rswag:specs:swaggerize` rake task (used by CI)
  # via its Railtie, so let Bundler auto-require it. rspec-rails comes with it
  # as a transitive runtime dependency.
  gem "rspec-rails"
  gem "rswag-specs"

  # Random data generation — only used in seed rake tasks
  gem "faker", require: false

  # technically not used for any of the scripts in the repo, but I like
  # to use it for scratch benchmarks
  gem "benchmark"
end

gem "rswag-api"
gem "rswag-ui"

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Preview emails in the browser [https://github.com/ryanb/letter_opener]
  gem "letter_opener"
  gem "letter_opener_web", "~> 3.0"

  # Bullet [https://github.com/flyerhzm/bullet]
  gem "bullet"

  # Backend for ActiveSupport::EventedFileUpdateChecker
  gem "listen"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "webmock"
end

group :production do
  # request.remote_ip behind Cloudflare [https://github.com/modosc/cloudflare-rails]
  gem "cloudflare-rails"
  gem "logtail-rails"
  gem "skylight"
  gem "aws-sdk-s3"
  gem "autotuner", "~> 1.0"

  gem "solid_cache"
  gem "solid_cable"

  gem "thruster"
end

gem "premailer-rails"

gem "doorkeeper", "~> 5.8"

gem "inertia_rails", "~> 3.21"

gem "vite_rails", "~> 3.11"

gem "rubyzip", "~> 3.3", require: false # only used by HeartbeatExportJob

gem "mailkick"
