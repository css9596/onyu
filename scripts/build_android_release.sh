#!/usr/bin/env bash
#
# Build a signed Android App Bundle ready for Google Play upload.
#
# Prerequisites:
#   - android/key.properties exists (copy from android/key.properties.example)
#   - upload keystore (.jks) at the path referenced in key.properties
#   - SUPABASE_URL and SUPABASE_ANON_KEY env vars set
#
# Output:
#   app/build/app/outputs/bundle/release/app-release.aab

set -euo pipefail

cd "$(dirname "$0")/../app"

if [[ ! -f android/key.properties ]]; then
  echo "ERROR: android/key.properties not found." >&2
  echo "  Copy android/key.properties.example and fill it in." >&2
  exit 1
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: SUPABASE_URL and SUPABASE_ANON_KEY must be exported." >&2
  echo "  Hint: source a local .env file before running this." >&2
  exit 1
fi

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build appbundle (release)"
flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "✅ Done. App bundle:"
echo "   app/build/app/outputs/bundle/release/app-release.aab"
echo
echo "Next: upload to Play Console → Internal testing → Create new release."
