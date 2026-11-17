#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid
rm -f /tmp/hackatime-ready

# Persistent volumes hide the image's dependencies after a rebuild. Refresh
# them before generating routes or building assets from the mounted source.
if [ -f /app/Gemfile ]; then
  cd /app && (bundle check || bundle install)
fi
if [ -f /app/package.json ]; then
  cd /app && bun install --frozen-lockfile
fi

# Generate js_from_routes TypeScript path helpers. These files are gitignored
# (see .gitignore) so they need to exist before Vite/svelte-check run. The
# Rails reloader regenerates on route changes during the dev session, but on
# a fresh container start app/javascript/api/ would otherwise be empty.
if [ -f /app/Gemfile ]; then
  cd /app && bundle exec rake js_from_routes:generate JS_FROM_ROUTES_FORCE=true || \
    echo "Warning: js_from_routes generation failed; Rails reloader will retry on first request"
fi

# Build Vite SSR bundle now that source code is mounted
if [ -f /app/package.json ]; then
  cd /app && bun run build:docs || \
    echo "Warning: Blume docs build failed; the Rails docs fallback will be used"
  cd /app && bin/vite build --ssr 2>/dev/null || \
    echo "Warning: Vite SSR build failed; will retry on next container start"
fi

# Compose waits for startup work before setup runs further build commands.
touch /tmp/hackatime-ready

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@"
