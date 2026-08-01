# syntax=docker/dockerfile:1.19
# check=error=true;skip=SecretsUsedInArgOrEnv

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t harbor .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name harbor harbor

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    fontconfig \
    libjemalloc2 \
    libvips \
    sqlite3 \
    libpq5 \
    tar \
    unzip \
    vim \
    wget && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash && \
    mv ~/.bun/bin/bun /usr/local/bin/

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Shared build packages for the parallel Ruby and JavaScript dependency stages.
FROM base AS build-base

# Install packages needed to build gems and convert the bundled web font into a
# TTF that librsvg/Pango can rasterize for generated OG images.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libpq-dev libyaml-dev nodejs woff2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies independently so BuildKit can run this stage
# in parallel with the Ruby dependency stage.
FROM build-base AS javascript-dependencies

COPY package.json bun.lock bunfig.toml ./
COPY patches patches
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun i --frozen-lockfile

RUN cp node_modules/@fontsource-variable/spline-sans/files/spline-sans-latin-wght-normal.woff2 /tmp/spline-sans-latin-wght-normal.woff2 && \
    woff2_decompress /tmp/spline-sans-latin-wght-normal.woff2 && \
    install -Dm644 /tmp/spline-sans-latin-wght-normal.ttf vendor/fonts/spline-sans-latin-wght-normal.ttf

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

# Combine dependencies with application source, excluding Blume-only inputs so
# documentation edits do not invalidate Rails asset compilation.
FROM build-base AS app-source

COPY --from=javascript-dependencies /rails/node_modules /rails/node_modules
COPY --from=javascript-dependencies /rails/vendor/fonts /rails/vendor/fonts
COPY --from=ruby-dependencies "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --exclude=blume.config.ts --exclude=docs . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Generate js_from_routes TypeScript path helpers. Must run before
# assets:precompile so Vite/Svelte can import from app/javascript/api/.
# These files are gitignored and regenerated on every build.
RUN SECRET_KEY_BASE_DUMMY=1 JS_FROM_ROUTES_FORCE=true ./bin/rake js_from_routes:generate

# Build Blume independently from Rails assets so both builds run concurrently.
FROM app-source AS docs-assets

COPY blume.config.ts ./
COPY docs docs
RUN bun run build:docs

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY.
# Tailwind is built via the Vite plugin (see app/javascript/entrypoints/application.css),
# so no separate tailwindcss:build step is needed.
FROM app-source AS rails-assets

RUN --mount=type=cache,target=/rails/node_modules/.vite \
    --mount=type=cache,target=/root/.bun/install/cache \
    --mount=type=cache,target=/root/.cache \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Combine generated assets and remove build-only JavaScript dependencies before
# the application is copied into the runtime image.
FROM rails-assets AS build

COPY --from=docs-assets /rails/public /rails/public
RUN rm -rf node_modules

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
COPY --from=build /usr/bin/git /usr/bin/git
COPY --from=build /usr/lib/git-core /usr/lib/git-core

# Make Spline Sans available to librsvg/libvips via fontconfig. Pango does not
# rasterize the bundled WOFF2 reliably, so production installs the converted TTF.
RUN install -Dm644 /rails/vendor/fonts/spline-sans-latin-wght-normal.ttf \
      /usr/local/share/fonts/spline-sans/spline-sans-latin-wght-normal.ttf && \
    fc-cache -f /usr/local/share/fonts/spline-sans

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

# Global git safeguards
RUN git config --system http.timeout 30 && \
    git config --system http.lowSpeedLimit 1000 && \
    git config --system http.lowSpeedTime 10
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start either web server or job worker based on WORKER env var
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
