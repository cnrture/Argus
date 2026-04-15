#!/usr/bin/env bash
#
# Install Sparkle command-line tools (generate_keys, sign_update) into
# ~/.sparkle-tools/bin so release.sh can sign update archives.
#
# Run this once per machine. Idempotent — re-running replaces the tools
# without touching your existing ed25519 keypair in the keychain.
#
# Usage:
#   ./scripts/setup-sparkle-tools.sh
#

set -euo pipefail

SPARKLE_VERSION="${SPARKLE_VERSION:-2.6.4}"
INSTALL_DIR="${HOME}/.sparkle-tools"
BIN_DIR="${INSTALL_DIR}/bin"

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m==>\033[0m %s\n" "$*" >&2; exit 1; }

command -v curl >/dev/null || fail "curl is required"
command -v unzip >/dev/null || fail "unzip is required"

mkdir -p "${BIN_DIR}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCHIVE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
ARCHIVE_PATH="${TMP_DIR}/sparkle.tar.xz"

info "downloading Sparkle ${SPARKLE_VERSION}"
curl -sSL "${ARCHIVE_URL}" -o "${ARCHIVE_PATH}"

info "extracting Sparkle tools"
tar -xJf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

for tool in generate_keys sign_update; do
    SRC=$(find "${TMP_DIR}" -type f -name "${tool}" -perm -u+x 2>/dev/null | head -1)
    [[ -n "${SRC}" ]] || fail "could not locate ${tool} in Sparkle archive"
    cp "${SRC}" "${BIN_DIR}/${tool}"
    chmod +x "${BIN_DIR}/${tool}"
    ok "installed ${tool} → ${BIN_DIR}/${tool}"
done

ok ""
ok "Sparkle tools installed at ${BIN_DIR}"
ok ""
ok "next step: generate an ed25519 keypair for Argus (separate from other apps):"
ok "  ${BIN_DIR}/generate_keys"
ok ""
ok "the public key will be printed — copy it into Argus/Info.plist as SUPublicEDKey."
ok "the private key is stored securely in your macOS login keychain."
ok "back it up with: ./scripts/backup-sparkle-key.sh"
