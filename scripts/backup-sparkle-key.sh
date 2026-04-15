#!/usr/bin/env bash
#
# Export the Sparkle ed25519 private key from the macOS login keychain
# to an encrypted file. Without this key you cannot ship updates that
# existing installs will accept — losing it means every user has to
# reinstall manually.
#
# Usage:
#   ./scripts/backup-sparkle-key.sh [output-path]
#
# Default output: ~/Documents/argus-sparkle-key-backup-YYYYMMDD.txt

set -euo pipefail

GENERATE_KEYS="${HOME}/.sparkle-tools/bin/generate_keys"
DEFAULT_OUT="${HOME}/Documents/argus-sparkle-key-backup-$(date +%Y%m%d).txt"
OUT_PATH="${1:-${DEFAULT_OUT}}"

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m==>\033[0m %s\n" "$*" >&2; exit 1; }

[[ -x "${GENERATE_KEYS}" ]] || fail "generate_keys not found at ${GENERATE_KEYS}. Run ./scripts/setup-sparkle-tools.sh first."

info "exporting Sparkle ed25519 private key from keychain"
info "you will be prompted by macOS to allow keychain access"

"${GENERATE_KEYS}" -x "${OUT_PATH}"

[[ -f "${OUT_PATH}" ]] || fail "backup file was not created at ${OUT_PATH}"

chmod 600 "${OUT_PATH}"

ok ""
ok "private key exported to: ${OUT_PATH}"
ok ""
ok "CRITICAL: move this file somewhere safe (1Password, encrypted USB, etc.)"
ok "then delete it from disk. anyone with this key can push malicious updates"
ok "to your users."
ok ""
ok "to restore on a new machine: ${GENERATE_KEYS} -f ${OUT_PATH}"
