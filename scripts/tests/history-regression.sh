#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# Compile the same model without the new indexes to seed an actual old store.
sed '/#Index<HistoryEntity>/d' Vega/Models/History/HistoryEntity.swift > "$test_dir/HistoryEntity.swift"
xcrun swiftc -parse-as-library -module-name HistoryRegression "$test_dir/HistoryEntity.swift" Vega/Managers/HistoryManager/HistoryManager.swift Vega/Utils/BrowserPerformance.swift scripts/tests/history-regression.swift -o "$test_dir/old"
"$test_dir/old" "$test_dir/history.store" seed
xcrun swiftc -parse-as-library -module-name HistoryRegression Vega/Models/History/HistoryEntity.swift Vega/Managers/HistoryManager/HistoryManager.swift Vega/Utils/BrowserPerformance.swift scripts/tests/history-regression.swift -o "$test_dir/new"
"$test_dir/new" "$test_dir/history.store"
