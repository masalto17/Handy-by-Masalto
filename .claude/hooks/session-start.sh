#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/home/user/flutter"
FLUTTER_BIN="$FLUTTER_DIR/bin"

# ── Install Flutter SDK if not present ──────────────────────────────
if [ ! -x "$FLUTTER_BIN/flutter" ]; then
  echo "Installing Flutter SDK (stable channel)..."
  git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

# Make flutter available for the rest of this script.
export PATH="$FLUTTER_BIN:$PATH"

# Persist PATH for the Claude session so flutter/dart are available
# in all subsequent Bash calls.
echo "export PATH=\"$FLUTTER_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# ── Precache web platform (the only one used in remote sessions) ────
flutter precache --web

# ── Install dependencies ────────────────────────────────────────────
cd "$CLAUDE_PROJECT_DIR"
flutter pub get

# ── Generate localizations (required before analyze / build) ────────
flutter gen-l10n

echo "Session start hook completed successfully."
