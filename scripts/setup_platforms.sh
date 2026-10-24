#!/usr/bin/env bash
# Regenerates the flutter platform folders locally and applies the custom
# Android widget overlay. Run once after cloning, or after switching branches.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not installed. See https://docs.flutter.dev/get-started/install"
  exit 1
fi

flutter create --platforms android,web .

rm -rf android/app/src/main/kotlin/com
cp -r platform_overlay/android/. android/

flutter pub get

echo "Done. Run 'flutter run -d windows' or 'flutter build apk --release'."