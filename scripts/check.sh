#!/bin/zsh
set -euo pipefail

cd "${0:A:h:h}"
alfaquest_sdk="$(xcrun --sdk macosx --show-sdk-path)"
alfaquest_output="$(mktemp -d /private/tmp/alfaquest-tests.XXXXXX)"
trap 'rm -rf "$alfaquest_output"' EXIT

xcrun swiftc -warnings-as-errors -strict-concurrency=complete -sdk "$alfaquest_sdk" \
  -module-cache-path /private/tmp/alfaquest-test-module-cache \
  AlfaQuest/Core/*.swift AlfaQuest/Storage/*.swift AlfaQuest/App/AppStore.swift \
  AlfaQuest/Camera/HuntObjectPlacement.swift \
  Tests/EngineTests.swift -o "$alfaquest_output/checks"
"$alfaquest_output/checks"
