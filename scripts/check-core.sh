#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/provectus-core.XXXXXX")
trap 'rm -f "$check_dir/core-checks"; rmdir "$check_dir"' EXIT
swiftc -warnings-as-errors Provectus/DomainModels.swift Provectus/OutputTemplateLibrary.swift CoreChecks/DomainRegressionTests.swift -o "$check_dir/core-checks"
"$check_dir/core-checks"
