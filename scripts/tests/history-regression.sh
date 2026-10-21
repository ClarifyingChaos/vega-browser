#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
# Compile the same model without the new indexes to seed an actual old store.
sed '/#Index<HistoryEntity>/d' Packages/VegaWeb/Sources/VegaWeb/HistoryEntity.swift > "$test_dir/HistoryEntity.swift"
xcrun swiftc -parse-as-library -module-name HistoryRegression "$test_dir/HistoryEntity.swift" Packages/VegaWeb/Sources/VegaWeb/HistoryManager.swift Packages/VegaWeb/Sources/VegaWeb/HistoryTextIndex.swift Packages/VegaWeb/Sources/VegaWeb/AutofillRanking.swift Packages/VegaWeb/Sources/VegaWeb/BrowserPerformance.swift scripts/tests/history-regression.swift -o "$test_dir/old"
"$test_dir/old" "$test_dir/history.store" seed
xcrun swiftc -parse-as-library -module-name HistoryRegression Packages/VegaWeb/Sources/VegaWeb/HistoryEntity.swift Packages/VegaWeb/Sources/VegaWeb/HistoryManager.swift Packages/VegaWeb/Sources/VegaWeb/HistoryTextIndex.swift Packages/VegaWeb/Sources/VegaWeb/AutofillRanking.swift Packages/VegaWeb/Sources/VegaWeb/BrowserPerformance.swift scripts/tests/history-regression.swift -o "$test_dir/new"
"$test_dir/new" "$test_dir/history.store"
