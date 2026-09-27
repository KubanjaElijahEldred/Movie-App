#!/usr/bin/env bash
#
# Build the Flutter web app and deploy the static output to Vercel.
#
# Vercel has no Flutter runtime, so the Flutter SDK builds the app and this
# script uploads the finished static bundle. The GitHub Actions workflow
# (.github/workflows/deploy.yml) runs the exact same steps on every push.
#
# Requires: VERCEL_TOKEN, VERCEL_ORG_ID and VERCEL_PROJECT_ID in the
# environment (or a Vercel CLI login plus an existing link).
#
set -euo pipefail

cd "$(dirname "$0")"

STAGE_DIR=".vercel-static"

echo "==> Resolving dependencies"
flutter pub get

echo "==> Building Flutter web (release)"
flutter build web --release --base-href /

echo "==> Staging static output in ${STAGE_DIR}"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp -R build/web/. "${STAGE_DIR}/"
cp vercel.json "${STAGE_DIR}/vercel.json"

echo "==> Deploying to Vercel"
npx --yes vercel@latest deploy --prod --yes "${STAGE_DIR}"

echo "==> Done. Adding ${STAGE_DIR}/ to .gitignore is handled in the repo."
