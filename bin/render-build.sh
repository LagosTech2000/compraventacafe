#!/usr/bin/env bash
# Render build command. Free instances have no pre-deploy step, so
# migrations run here, before the new version starts serving.
set -o errexit

bundle install
bin/rails assets:precompile
bin/rails assets:clean
bin/rails db:migrate

# Creates the first administrator once ADMIN_NAME, ADMIN_EMAIL and
# ADMIN_PASSWORD are set in Render. Idempotent (see db/seeds.rb).
if [ -n "$ADMIN_EMAIL" ]; then
  bin/rails db:seed
fi
