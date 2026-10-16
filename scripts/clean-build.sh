#!/bin/sh
# Remove generated project-local build outputs and caches.
set -eu
cd "$(dirname "$0")/.."
rm -rf -- .build android/.gradle android/build android/app/build
printf '%s\n' 'Build files cleaned.'
