#!/bin/bash
set -e

rm -f tmp/pids/server.pid

if [ -f Gemfile ]; then
  bundle exec rake js_from_routes:generate JS_FROM_ROUTES_FORCE=true || \
    echo "Warning: js_from_routes generation failed; Rails reloader will retry on first request"
fi

if [ -f package.json ]; then
  bin/vite build --ssr 2>/dev/null || \
    echo "Warning: Vite SSR build failed; will retry on next container start"
fi

exec "$@"
