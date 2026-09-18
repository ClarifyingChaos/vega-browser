#!/bin/sh
# Builds libvega_adblock.a (release, stripped) for macOS arm64, iOS arm64 and the iOS
# simulator and wraps them in VegaAdblock.xcframework so machines without a Rust
# toolchain can still build Vega.
set -eu
cd "$(dirname "$0")"
export PATH="$HOME/.cargo/bin:$PATH"
# Keep cargo output out of Vega/ (a filesystem-synchronized Xcode group would
# otherwise copy every target/ file into the app bundle). build/ is gitignored.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PWD/../../../build/AdblockRustFFI-target}"

cargo test --release
cargo build --release --target aarch64-apple-darwin
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
rm -rf VegaAdblock.xcframework
xcodebuild -create-xcframework \
  -library "$CARGO_TARGET_DIR/aarch64-apple-darwin/release/libvega_adblock.a" -headers include \
  -library "$CARGO_TARGET_DIR/aarch64-apple-ios/release/libvega_adblock.a" -headers include \
  -library "$CARGO_TARGET_DIR/aarch64-apple-ios-sim/release/libvega_adblock.a" -headers include \
  -output VegaAdblock.xcframework
ls VegaAdblock.xcframework
