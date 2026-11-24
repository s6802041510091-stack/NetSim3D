#!/bin/sh
# Net-Desktop's frontend calls "/api/..." from the site root. Under /sim/ those calls
# would reach the main website's API, so turn them into relative "api/..." calls.
# Remove this script once Net-Desktop itself uses relative paths.
set -e
cd "$1"
sed -i -E "s#([\"'\`])/api/#\1api/#g" js/*.js *.html
sed -i 's#href="/"#href="./"#g' *.html
if grep -rnE "[\"'\`]/api/|href=\"/\"" js *.html; then
  echo "patch-paths: absolute paths are still left (above)" >&2
  exit 1
fi
echo "patch-paths: Net-Desktop frontend now uses relative paths"
