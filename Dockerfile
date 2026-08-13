# syntax=docker/dockerfile:1.19
# check=error=true;skip=SecretsUsedInArgOrEnv

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t harbor .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name harbor harbor

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.6

# Bun 1.4 canary includes the package alias fix needed for the TypeScript 7 migration.
FROM docker.io/oven/bun:canary-slim@sha256:6e28b54849cf680251afd7ed83e24375dfe47b6f78c8bfdb7e98bf12a6fa9f2e AS bun

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS ruby-base

# Rails app lives here
WORKDIR /rails

# Keeping Bun on the common parent makes the same pinned binary available to
# dependency installation, asset compilation, and the production SSR runtime.
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
    curl \
    fontconfig \
    libjemalloc2 \
    tar && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install only the compiler toolchain needed by native gems.
FROM ruby-base AS build-base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y g++ gcc make && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Git and the font conversion tool independently so native gem
# compilation does not wait for unrelated build packages.
FROM ruby-base AS frontend-base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y git woff2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install JavaScript dependencies independently so BuildKit can run this stage
# in parallel with the Ruby dependency stage.
FROM frontend-base AS javascript-dependencies

COPY package.json bun.lock bunfig.toml ./
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun i --frozen-lockfile --linker=isolated && \
    mkdir -p node_modules/.vite-client node_modules/.vite-ssr node_modules/.vite-temp

RUN cp node_modules/@fontsource-variable/spline-sans/files/spline-sans-latin-wght-normal.woff2 /tmp/spline-sans-latin-wght-normal.woff2 && \
    woff2_decompress /tmp/spline-sans-latin-wght-normal.woff2 && \
    install -Dm644 /tmp/spline-sans-latin-wght-normal.ttf vendor/fonts/spline-sans-latin-wght-normal.ttf

# Sharp ships one libvips binary with its codecs. Ruby Vips loads the same ABI.
FROM javascript-dependencies AS libvips

RUN mkdir /libvips && \
    cp node_modules/@img/sharp-libvips-linux-*/lib/libvips-cpp.so.* /libvips/libvips-cpp.so

# Prepare the runtime concurrently with dependency and asset compilation.
FROM runtime-base AS prepared-runtime

ENV LD_LIBRARY_PATH="/usr/local/lib"

COPY --from=frontend-base /usr/bin/git /usr/bin/git
COPY --from=frontend-base /usr/lib/git-core /usr/lib/git-core
COPY --from=libvips /libvips/libvips-cpp.so /usr/local/lib/libvips-cpp.so
COPY --from=javascript-dependencies /rails/vendor/fonts/spline-sans-latin-wght-normal.ttf \
    /usr/local/share/fonts/spline-sans/spline-sans-latin-wght-normal.ttf

RUN ln -s libvips-cpp.so /usr/local/lib/libvips.so.42 && \
    fc-cache -f /usr/local/share/fonts/spline-sans && \
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
    BUNDLER_VERSION="$(awk 'END { print $1 }' Gemfile.lock)" && \
    (gem list --installed bundler --version "$BUNDLER_VERSION" || \
      gem install bundler --version "$BUNDLER_VERSION" --no-document) && \
    bundle "_${BUNDLER_VERSION}_" install && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application source without persisting build-only dependencies in its
# layers. Rails and Blume consume those dependencies through read-only mounts.
FROM ruby-base AS application-source

COPY --from=javascript-dependencies /rails/vendor/fonts /rails/vendor/fonts
COPY --exclude=blume.config.ts --exclude=docs . .

# Build Blume from only its inputs so Rails application changes neither
# invalidate nor delay documentation generation.
FROM ruby-base AS docs-assets

COPY package.json blume.config.ts theme.css ./
COPY config/themes.yml config/themes.yml
COPY public public
COPY docs docs
RUN --mount=type=bind,from=javascript-dependencies,source=/rails/node_modules,target=/rails/node_modules,rw \
    bun run build:docs

# Generate route helpers before the two asset branches start.
FROM application-source AS route-helpers

RUN --network=none \
    --mount=type=bind,from=ruby-dependencies,source=/usr/local/bundle,target=/usr/local/bundle \
    export SECRET_KEY_BASE_DUMMY=1 JS_FROM_ROUTES_FORCE=true && \
    AWS_EC2_METADATA_DISABLED=true \
      S3_BUCKET=dummy S3_ACCESS_KEY_ID=dummy S3_SECRET_ACCESS_KEY=dummy S3_ENDPOINT=http://127.0.0.1 \
      ./bin/rake js_from_routes:generate

# Build Rails assets in one Rails process. Save its Bootsnap cache in the image
# so production does not compile the same Ruby files again at boot.
FROM route-helpers AS rails-assets

RUN --network=none \
    --mount=type=bind,from=ruby-dependencies,source=/usr/local/bundle,target=/usr/local/bundle \
    --mount=type=cache,target=/root/.cache/bootsnap \
    export SECRET_KEY_BASE_DUMMY=1 BOOTSNAP_CACHE_DIR=/root/.cache/bootsnap \
      VITE_RUBY_SKIP_ASSETS_PRECOMPILE_EXTENSION=true && \
    AWS_EC2_METADATA_DISABLED=true \
      S3_BUCKET=dummy S3_ACCESS_KEY_ID=dummy S3_SECRET_ACCESS_KEY=dummy S3_ENDPOINT=http://127.0.0.1 \
      ./bin/rails runner 'Rails.application.eager_load!; Rails.application.load_tasks; Rake::Task["assets:precompile"].invoke' && \
    rm -rf tmp/cache/bootsnap && \
    cp -a "$BOOTSNAP_CACHE_DIR/bootsnap" tmp/cache/bootsnap

# Build Vite from only the files that can affect its output. Tailwind scans
# Rails controllers, helpers, and views in addition to the JavaScript source.
FROM ruby-base AS frontend-assets

COPY app/javascript app/javascript
COPY app/assets/tailwind app/assets/tailwind
COPY app/controllers app/controllers
COPY app/helpers app/helpers
COPY app/views app/views
COPY config/vite.json config/vite.json
COPY package.json ./
COPY svelte.config.js ./
COPY tsconfig.json tsconfig.node.json ./
COPY vite.config.ts ./
COPY --from=route-helpers /rails/app/javascript/api app/javascript/api

RUN --mount=type=bind,from=javascript-dependencies,source=/rails/node_modules,target=/rails/node_modules \
    --mount=type=cache,target=/rails/node_modules/.vite-client \
    --mount=type=cache,target=/rails/node_modules/.vite-ssr \
    --mount=type=tmpfs,target=/rails/node_modules/.vite-temp \
    --mount=type=cache,target=/root/.bun/install/cache \
    (VITE_CACHE_DIR=node_modules/.vite-client bun x --bun vite build & \
      client_pid=$!; \
      VITE_CACHE_DIR=node_modules/.vite-ssr bun x --bun vite build --ssr & \
      ssr_pid=$!; \
      wait "$client_pid" && \
      wait "$ssr_pid")

# Combine generated Rails, Vite, and documentation assets.
FROM rails-assets AS build

COPY --from=frontend-assets /rails/public /rails/public
COPY --from=docs-assets /rails/public /rails/public

# Final stage for app image
FROM prepared-runtime

# Copy built artifacts: gems, application
COPY --from=ruby-dependencies "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --exclude=db --exclude=log --exclude=spec --exclude=storage --exclude=test --exclude=tmp /rails /rails
COPY --from=build --chown=1000:1000 /rails/db /rails/db
COPY --from=build --chown=1000:1000 /rails/log /rails/log
COPY --from=build --chown=1000:1000 /rails/storage /rails/storage
COPY --from=build --chown=1000:1000 /rails/tmp /rails/tmp

ARG SOURCE_COMMIT=unknown
RUN printf '%s\n' "$SOURCE_COMMIT" > REVISION

USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start either web server or job worker based on WORKER env var
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
