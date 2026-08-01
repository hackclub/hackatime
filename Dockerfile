# syntax=docker/dockerfile:1.19
# check=error=true;skip=SecretsUsedInArgOrEnv

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t harbor .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name harbor harbor

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
ARG BUN_VERSION=1.3.10

FROM docker.io/oven/bun:$BUN_VERSION-slim AS bun

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS ruby-base

# Rails app lives here
WORKDIR /rails

# Use a pinned Bun binary in both the build and runtime branches. Keeping this
# on their common parent lets the expensive apt installs below run in parallel.
COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Build the runtime base independently from application dependencies so these
# packages are installed in parallel with the builder toolchain and Bundler.
FROM ruby-base AS runtime-base

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    fontconfig \
    libjemalloc2 \
    libvips \
    sqlite3 \
    libpq5 \
    tar && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Shared build packages for the parallel Ruby and JavaScript dependency stages.
FROM ruby-base AS build-base

# Install packages needed to build gems and convert the bundled web font into a
# TTF that librsvg/Pango can rasterize for generated OG images. PostgreSQL and
# SQLite use the lockfile's precompiled gems, so their development headers are
# not needed here.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git nodejs woff2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies independently so BuildKit can run this stage
# in parallel with the Ruby dependency stage.
FROM build-base AS javascript-dependencies

COPY package.json bun.lock bunfig.toml ./
COPY patches patches
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun i --frozen-lockfile && \
    mkdir -p node_modules/.vite-client node_modules/.vite-ssr

RUN cp node_modules/@fontsource-variable/spline-sans/files/spline-sans-latin-wght-normal.woff2 /tmp/spline-sans-latin-wght-normal.woff2 && \
    woff2_decompress /tmp/spline-sans-latin-wght-normal.woff2 && \
    install -Dm644 /tmp/spline-sans-latin-wght-normal.ttf vendor/fonts/spline-sans-latin-wght-normal.ttf

# Prepare the runtime concurrently with dependency and asset compilation.
FROM runtime-base AS prepared-runtime

COPY --from=build-base /usr/bin/git /usr/bin/git
COPY --from=build-base /usr/lib/git-core /usr/lib/git-core
COPY --from=javascript-dependencies /rails/vendor/fonts/spline-sans-latin-wght-normal.ttf \
    /usr/local/share/fonts/spline-sans/spline-sans-latin-wght-normal.ttf

RUN fc-cache -f /usr/local/share/fonts/spline-sans && \
    groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    git config --system http.timeout 30 && \
    git config --system http.lowSpeedLimit 1000 && \
    git config --system http.lowSpeedTime 10

# Install gems independently from JavaScript dependencies.
FROM build-base AS ruby-dependencies

COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/root/.bundle/cache \
    --mount=type=cache,target=/usr/local/bundle/ruby/4.0.0/cache \
    BUNDLER_VERSION="$(tail -n 1 Gemfile.lock)" && \
    gem install bundler --version "$BUNDLER_VERSION" && \
    bundle "_${BUNDLER_VERSION}_" install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application source without persisting build-only dependencies in its
# layers. Rails and Blume consume those dependencies through read-only mounts.
FROM build-base AS application-source

COPY --from=javascript-dependencies /rails/vendor/fonts /rails/vendor/fonts
COPY --exclude=blume.config.ts --exclude=docs . .

# Precompile bootsnap code for faster boot times
RUN --mount=type=bind,from=ruby-dependencies,source=/usr/local/bundle,target=/usr/local/bundle \
    bundle exec bootsnap precompile app/ lib/

# Build Blume from only its inputs so Rails application changes neither
# invalidate nor delay documentation generation.
FROM ruby-base AS docs-assets

COPY package.json blume.config.ts theme.css ./
COPY config/themes.yml config/themes.yml
COPY public public
COPY docs docs
RUN --mount=type=bind,from=javascript-dependencies,source=/rails/node_modules,target=/rails/node_modules,rw \
    bun run build:docs

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY.
# Tailwind is built via the Vite plugin (see app/javascript/entrypoints/application.css),
# so no separate tailwindcss:build step is needed.
FROM application-source AS rails-assets

RUN --mount=type=bind,from=ruby-dependencies,source=/usr/local/bundle,target=/usr/local/bundle \
    --mount=type=bind,from=javascript-dependencies,source=/rails/node_modules,target=/rails/node_modules,rw \
    --mount=type=cache,target=/rails/node_modules/.vite-client \
    --mount=type=cache,target=/rails/node_modules/.vite-ssr \
    --mount=type=cache,target=/root/.bun/install/cache \
    --mount=type=cache,target=/root/.cache \
    export SECRET_KEY_BASE_DUMMY=1 JS_FROM_ROUTES_FORCE=true && \
    VITE_RUBY_SKIP_ASSETS_PRECOMPILE_EXTENSION=true \
      ./bin/rake js_from_routes:generate assets:precompile && \
    (VITE_CACHE_DIR=node_modules/.vite-client ./bin/vite build & \
      client_pid=$!; \
      VITE_CACHE_DIR=node_modules/.vite-ssr ./bin/vite build --ssr & \
      ssr_pid=$!; \
      wait "$client_pid" && \
      wait "$ssr_pid")

# Combine generated Rails and documentation assets.
FROM rails-assets AS build

COPY --from=docs-assets /rails/public /rails/public

# Final stage for app image
FROM prepared-runtime

# Copy built artifacts: gems, application
COPY --from=ruby-dependencies "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --exclude=db --exclude=log --exclude=storage --exclude=tmp /rails /rails
COPY --from=build --chown=1000:1000 /rails/db /rails/db
COPY --from=build --chown=1000:1000 /rails/log /rails/log
COPY --from=build --chown=1000:1000 /rails/storage /rails/storage
COPY --from=build --chown=1000:1000 /rails/tmp /rails/tmp

USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start either web server or job worker based on WORKER env var
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
