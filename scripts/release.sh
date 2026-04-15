#!/usr/bin/env bash
#
# Release pipeline for Argus:
#   xcodebuild archive → export → sign → notarize → staple
#   → DMG (for Homebrew cask) + ZIP (for Sparkle)
#   → Sparkle ed25519 sign → update appcast.xml
#
# Requirements:
#   - Xcode installed and selected (xcode-select)
#   - "Developer ID Application: CANER TURE (39Z244SGXG)" in keychain
#   - notarytool keychain profile 'ArgusNotary' (see below to create)
#   - Sparkle tools at ~/.sparkle-tools/bin (run ./scripts/setup-sparkle-tools.sh)
#   - SUPublicEDKey set in Argus/Info.plist
#
# One-time notarytool profile setup:
#   xcrun notarytool store-credentials ArgusNotary \
#     --apple-id you@example.com \
#     --team-id 39Z244SGXG \
#     --password <app-specific-password>
#
# Usage:
#   ./scripts/release.sh
#
# Optional env overrides:
#   SIGNING_IDENTITY, NOTARY_PROFILE, BUNDLE_ID, SPARKLE_TOOLS

set -euo pipefail

# ---- config ----
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: CANER TURE (39Z244SGXG)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ArgusNotary}"
BUNDLE_ID="${BUNDLE_ID:-com.cnrture.Argus}"
SPARKLE_TOOLS="${SPARKLE_TOOLS:-${HOME}/.sparkle-tools/bin}"
APP_NAME="Argus"
SCHEME="Argus"

# ---- paths ----
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_PROJECT_DIR="${REPO_ROOT}/Argus"
PROJECT_FILE="${XCODE_PROJECT_DIR}/Argus.xcodeproj"
BUILD_DIR="${REPO_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
EXPORT_OPTIONS="${XCODE_PROJECT_DIR}/ExportOptions.plist"
APP_BUNDLE="${EXPORT_DIR}/${APP_NAME}.app"
RELEASE_DIR="${REPO_ROOT}/release"
ZIP_PATH="${RELEASE_DIR}/${APP_NAME}.zip"
DMG_PATH="${RELEASE_DIR}/${APP_NAME}.dmg"
INFO_PLIST="${XCODE_PROJECT_DIR}/Argus/Info.plist"

# ---- helpers ----
info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m==>\033[0m %s\n" "$*" >&2; exit 1; }

# ---- preflight ----
command -v xcodebuild >/dev/null || fail "xcodebuild not found"
command -v codesign >/dev/null || fail "codesign not found"
command -v xcrun >/dev/null || fail "xcrun not found"
command -v hdiutil >/dev/null || fail "hdiutil not found"
[[ -d "${PROJECT_FILE}" ]] || fail "Xcode project missing at ${PROJECT_FILE}"
[[ -f "${EXPORT_OPTIONS}" ]] || fail "ExportOptions.plist missing at ${EXPORT_OPTIONS}"

security find-identity -v -p codesigning 2>/dev/null | grep -qF "${SIGNING_IDENTITY}" \
    || fail "signing identity not found in keychain: ${SIGNING_IDENTITY}"

xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1 \
    || fail "notarytool profile '${NOTARY_PROFILE}' not found. See header of this script for setup."

[[ -x "${SPARKLE_TOOLS}/sign_update" ]] \
    || fail "Sparkle sign_update not found at ${SPARKLE_TOOLS}. Run ./scripts/setup-sparkle-tools.sh first."

grep -q "SUPublicEDKey" "${INFO_PLIST}" \
    || fail "SUPublicEDKey missing in ${INFO_PLIST}. Run ${SPARKLE_TOOLS}/generate_keys and add the public key."

# ---- read version from Xcode project ----
info "reading version from Xcode project settings"
BUILD_SETTINGS=$(xcodebuild -project "${PROJECT_FILE}" -scheme "${SCHEME}" -configuration Release -showBuildSettings 2>/dev/null)
VERSION=$(echo "${BUILD_SETTINGS}" | awk -F' = ' '/^ *MARKETING_VERSION / {print $2; exit}')
BUILD_NUMBER=$(echo "${BUILD_SETTINGS}" | awk -F' = ' '/^ *CURRENT_PROJECT_VERSION / {print $2; exit}')
[[ -n "${VERSION}" ]] || fail "could not read MARKETING_VERSION"
[[ -n "${BUILD_NUMBER}" ]] || fail "could not read CURRENT_PROJECT_VERSION"
info "version: ${VERSION} (build ${BUILD_NUMBER})"

# ---- clean ----
info "cleaning previous build artifacts"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}" "${ZIP_PATH}" "${DMG_PATH}"
mkdir -p "${BUILD_DIR}" "${RELEASE_DIR}"

# ---- archive ----
# Argus requires macOS 15+ (Apple Silicon). Building arm64-only avoids a Swift
# compiler IR crash on x86_64 for generic NSHostingView subclasses in Xcode 26.
info "creating Xcode archive (Release, arm64)"
xcodebuild archive \
    -project "${PROJECT_FILE}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination 'generic/platform=macOS' \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
    DEVELOPMENT_TEAM=39Z244SGXG

[[ -d "${ARCHIVE_PATH}" ]] || fail "archive not created at ${ARCHIVE_PATH}"

# ---- export ----
# Xcode 26 dropped the `developer-id` method from -exportArchive's plist
# schema. The archive is already signed correctly with Developer ID above,
# so we copy the .app directly out of the xcarchive instead.
info "exporting .app from archive"
rm -rf "${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_BUNDLE}"

[[ -d "${APP_BUNDLE}" ]] || fail ".app not exported at ${APP_BUNDLE}"

# Re-sign nested binaries inside Sparkle.framework with Developer ID +
# secure timestamp. Xcode's archive phase doesn't re-sign these because we
# skipped -exportArchive. Order matters: deepest binaries first.
info "re-signing Sparkle framework internals with Developer ID"
SPARKLE_FW="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
if [[ -d "${SPARKLE_FW}" ]]; then
    SPARKLE_VERSION_DIR="${SPARKLE_FW}/Versions/B"
    # Nested binaries and helpers
    for target in \
        "${SPARKLE_VERSION_DIR}/Autoupdate" \
        "${SPARKLE_VERSION_DIR}/Updater.app/Contents/MacOS/Updater" \
        "${SPARKLE_VERSION_DIR}/Updater.app" \
        "${SPARKLE_VERSION_DIR}/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
        "${SPARKLE_VERSION_DIR}/XPCServices/Installer.xpc" \
        "${SPARKLE_VERSION_DIR}/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
        "${SPARKLE_VERSION_DIR}/XPCServices/Downloader.xpc" \
        "${SPARKLE_FW}"; do
        if [[ -e "${target}" ]]; then
            codesign --force --sign "${SIGNING_IDENTITY}" \
                --timestamp --options runtime \
                "${target}"
        fi
    done
fi

# Finally re-sign the app bundle itself so the outer signature covers the
# updated framework contents.
info "re-signing app bundle"
codesign --force --sign "${SIGNING_IDENTITY}" \
    --timestamp --options runtime \
    --entitlements "${XCODE_PROJECT_DIR}/Argus/Argus.entitlements" \
    "${APP_BUNDLE}"

# ---- verify signature ----
info "verifying code signature"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}" 2>&1 | tail -5

# ---- notarize (zip first — notarytool accepts zip/dmg/pkg) ----
info "creating notarization archive"
NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
rm -f "${NOTARIZE_ZIP}"
/usr/bin/ditto -c -k --keepParent "${APP_BUNDLE}" "${NOTARIZE_ZIP}"

info "submitting to Apple notary service (this may take a few minutes)"
xcrun notarytool submit "${NOTARIZE_ZIP}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

info "stapling notarization ticket to .app"
xcrun stapler staple "${APP_BUNDLE}"
xcrun stapler validate "${APP_BUNDLE}"

# ---- gatekeeper sanity check ----
info "gatekeeper assessment"
spctl -a -vvv -t install "${APP_BUNDLE}" 2>&1 | tail -5 || true

# ---- create distribution ZIP (for Sparkle) ----
info "creating distribution ZIP for Sparkle"
/usr/bin/ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

# ---- create DMG (for Homebrew cask + direct download) ----
info "creating DMG"
DMG_STAGING="${BUILD_DIR}/dmg-staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDZO \
    "${DMG_PATH}" >/dev/null

info "signing DMG"
codesign --force --sign "${SIGNING_IDENTITY}" --timestamp "${DMG_PATH}"

info "notarizing DMG"
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

info "stapling DMG"
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

rm -rf "${DMG_STAGING}"

# ---- sign ZIP with Sparkle ed25519 ----
info "signing release ZIP with Sparkle sign_update"
SIGN_OUTPUT=$("${SPARKLE_TOOLS}/sign_update" "${ZIP_PATH}")
ED_SIGNATURE=$(echo "${SIGN_OUTPUT}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LENGTH=$(echo "${SIGN_OUTPUT}" | sed -n 's/.*length="\([^"]*\)".*/\1/p')
[[ -n "${ED_SIGNATURE}" ]] || fail "could not extract ed25519 signature from: ${SIGN_OUTPUT}"
[[ -n "${LENGTH}" ]] || fail "could not extract length from: ${SIGN_OUTPUT}"
info "ed25519 signature: ${ED_SIGNATURE:0:16}..."

# ---- sha256 for Homebrew cask ----
DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

# ---- update appcast ----
RELEASE_NOTES_FILE="${REPO_ROOT}/RELEASE_NOTES_${VERSION}.md"
if [[ -f "${RELEASE_NOTES_FILE}" ]]; then
    RELEASE_NOTES_CONTENT=$(cat "${RELEASE_NOTES_FILE}")
else
    RELEASE_NOTES_CONTENT="Argus ${VERSION}"
fi

info "updating appcast.xml with v${VERSION}"
"${REPO_ROOT}/scripts/update-appcast.sh" \
    --version "${VERSION}" \
    --short-version "${VERSION}" \
    --zip "${ZIP_PATH}" \
    --ed-signature "${ED_SIGNATURE}" \
    --length "${LENGTH}" \
    --release-notes "${RELEASE_NOTES_CONTENT}"

# ---- summary ----
ok ""
ok "Release artifacts ready:"
ok "  ZIP (Sparkle): ${ZIP_PATH}"
ok "  DMG (cask):    ${DMG_PATH}"
ok "  DMG sha256:    ${DMG_SHA256}"
ok ""
ok "Next steps (manual):"
ok "  1. Commit the updated appcast:"
ok "     git add appcast.xml"
ok "     git commit -m 'release: appcast entry for v${VERSION}'"
ok "     git push"
ok ""
ok "  2. Copy appcast.xml into Argus-Website and deploy (zero-downtime blue-green):"
ok "     cp appcast.xml ../Argus-Website/public/appcast.xml"
ok "     cd ../Argus-Website && ./deploy-docker.sh"
ok "     # Verify: curl -I https://argus.candroid.dev/appcast.xml"
ok ""
ok "  2. Create GitHub release:"
ok "     gh release create v${VERSION} \\"
ok "         '${ZIP_PATH}' '${DMG_PATH}' \\"
ok "         --title 'Argus v${VERSION}' \\"
if [[ -f "${RELEASE_NOTES_FILE}" ]]; then
    ok "         --notes-file '${RELEASE_NOTES_FILE}'"
else
    ok "         --notes 'Argus v${VERSION}'"
fi
ok ""
ok "  3. Update Homebrew cask (Casks/argus.rb):"
ok "     version \"${VERSION}\""
ok "     sha256 \"${DMG_SHA256}\""
