#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path=.build/ModuleCache -framework Foundation -I ios/SailPunchlist \
    ios/SailPunchlist/SailStore.m tests/store-tests.m -o .build/store-tests
.build/store-tests "$PWD/checklists.json"
