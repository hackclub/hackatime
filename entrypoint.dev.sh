#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Generate js_from_routes TypeScript path helpers. These files are gitignored
# (see .gitignore) so they need to exist before Vite/svelte-check run. The
# Rails reloader regenerates on route changes during the dev session, but on
# a fresh container start app/javascript/api/ would otherwise be empty.
if [ -f /app/Gemfile ]; then
  cd /app && bundle exec rake js_from_routes:generate JS_FROM_ROUTES_FORCE=true || \
    echo "Warning: js_from_routes generation failed; Rails reloader will retry on first request"
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@"