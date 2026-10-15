#!/usr/bin/env bash
# Build steps Render runs on every deploy. Exit on first error.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails db:migrate
bundle exec rails db:seed
