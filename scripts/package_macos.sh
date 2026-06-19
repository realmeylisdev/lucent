#!/usr/bin/env bash
#
# Package the release macOS .app into dist/lucent-macos.dmg.
#
# Behavior is CONDITIONAL on the presence of Apple signing secrets (all passed
# in as environment variables by the workflow):
#
#   * If a Developer-ID signing identity + cert are present, the .app is
#     codesigned with the hardened runtime, packed into a DMG, the DMG is
#     notarized (notarytool --wait) and stapled.
#   * Otherwise the .app is ad-hoc signed and packed into an UNSIGNED DMG. The
#     job still succeeds; users must clear quarantine to run it (see warning).
#
# The script ALWAYS exits 0 on success and ALWAYS produces dist/lucent-macos.dmg
# so the build job succeeds with no secrets configured.
#
# Required env (only when signing): MACOS_CERT_P12_BASE64, MACOS_CERT_PASSWORD,
#   MACOS_KEYCHAIN_PASSWORD, MACOS_SIGN_IDENTITY.
# Required env (only when notarizing): EITHER
#   AC_API_KEY_ID + AC_API_ISSUER_ID + AC_API_KEY_BASE64
#   OR APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD.

set -euo pipefail

APP_NAME="lucent"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="dist/lucent-macos.dmg"
ENTITLEMENTS="macos/Runner/Release.entitlements"

mkdir -p dist

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: expected app not found at $APP_PATH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Decide whether we can sign. We need ALL four signing inputs to be non-empty.
# ---------------------------------------------------------------------------
CAN_SIGN=0
if [ -n "${MACOS_CERT_P12_BASE64:-}" ] \
  && [ -n "${MACOS_CERT_PASSWORD:-}" ] \
  && [ -n "${MACOS_KEYCHAIN_PASSWORD:-}" ] \
  && [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  CAN_SIGN=1
fi

# Decide which notarization method (if any) is available.
NOTARIZE_METHOD="none"
if [ -n "${AC_API_KEY_ID:-}" ] && [ -n "${AC_API_ISSUER_ID:-}" ] \
  && [ -n "${AC_API_KEY_BASE64:-}" ]; then
  NOTARIZE_METHOD="apikey"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] \
  && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
  NOTARIZE_METHOD="appleid"
fi

make_dmg() {
  # $1 = source .app path. Builds a compressed DMG at $DMG_PATH.
  rm -f "$DMG_PATH"
  local staging
  staging="$(mktemp -d)"
  cp -R "$1" "$staging/"
  ln -s /Applications "$staging/Applications"
  hdiutil create \
    -volname "Lucent" \
    -srcfolder "$staging" \
    -ov -format UDZO \
    "$DMG_PATH"
  rm -rf "$staging"
}

if [ "$CAN_SIGN" -eq 0 ]; then
  # -------------------------------------------------------------------------
  # UNSIGNED PATH — no secrets. Ad-hoc sign so the app is runnable locally,
  # then build an unsigned DMG. Succeeds and uploads.
  # -------------------------------------------------------------------------
  echo "::warning title=Unsigned macOS build::No Developer-ID secrets configured. Producing an UNSIGNED (ad-hoc) DMG. Gatekeeper will block it on other Macs; users must run: xattr -dr com.apple.quarantine /Applications/lucent.app"
  echo "Ad-hoc signing $APP_PATH ..."
  codesign --force --deep --sign - "$APP_PATH" || true
  make_dmg "$APP_PATH"
  echo "Built UNSIGNED DMG at $DMG_PATH"
  exit 0
fi

# ---------------------------------------------------------------------------
# SIGNED PATH — import cert into a temporary keychain.
# ---------------------------------------------------------------------------
echo "Developer-ID secrets present. Signing + notarizing."

KEYCHAIN="$RUNNER_TEMP/lucent-signing.keychain-db"
CERT_PATH="$RUNNER_TEMP/lucent-cert.p12"

cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -f "$CERT_PATH" "${RUNNER_TEMP}/lucent_ac_key.p8" 2>/dev/null || true
}
trap cleanup EXIT

echo "$MACOS_CERT_P12_BASE64" | base64 --decode > "$CERT_PATH"

security create-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERT_PATH" -P "$MACOS_CERT_PASSWORD" \
  -A -t cert -f pkcs12 -k "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "$MACOS_KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
# Put our keychain first in the search list so codesign finds the identity.
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | sed s/\"//g)

echo "Codesigning with identity: $MACOS_SIGN_IDENTITY"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$MACOS_SIGN_IDENTITY" \
  "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

make_dmg "$APP_PATH"
echo "Signing DMG ..."
codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$DMG_PATH"

# ---------------------------------------------------------------------------
# Notarize, if creds are present.
# ---------------------------------------------------------------------------
if [ "$NOTARIZE_METHOD" = "none" ]; then
  echo "::warning title=Signed but not notarized::Developer-ID signed, but no notarytool credentials were provided. The DMG is signed but NOT notarized; Gatekeeper may still warn. Provide AC_API_* or APPLE_* secrets to notarize."
  echo "Built SIGNED (not notarized) DMG at $DMG_PATH"
  exit 0
fi

echo "Submitting $DMG_PATH to notarytool ($NOTARIZE_METHOD) ..."
if [ "$NOTARIZE_METHOD" = "apikey" ]; then
  KEY_PATH="$RUNNER_TEMP/lucent_ac_key.p8"
  echo "$AC_API_KEY_BASE64" | base64 --decode > "$KEY_PATH"
  xcrun notarytool submit "$DMG_PATH" \
    --key "$KEY_PATH" \
    --key-id "$AC_API_KEY_ID" \
    --issuer "$AC_API_ISSUER_ID" \
    --wait
else
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
fi

echo "Stapling notarization ticket ..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Built SIGNED + NOTARIZED + STAPLED DMG at $DMG_PATH"
