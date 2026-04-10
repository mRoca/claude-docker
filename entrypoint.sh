#!/usr/bin/env bash
set -euo pipefail

# GCS_BUCKET value from https://claude.ai/install.sh
GCS="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

VERSIONS_DIR="$HOME/.claude/docker/versions"
mkdir -p "$VERSIONS_DIR"

case "$(uname -m)" in
    x86_64)  CLAUDE_PLATFORM="linux-x64" ;;
    aarch64) CLAUDE_PLATFORM="linux-arm64" ;;
    *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

_latest=$(curl -sf --max-time 5 "$GCS/latest" 2>/dev/null || true)

if [[ -n "$_latest" ]]; then
    CLAUDE_BIN="$VERSIONS_DIR/$_latest"
else
    # Offline fallback: use the most recently downloaded version
    CLAUDE_BIN=$(find "$VERSIONS_DIR" -maxdepth 1 -type f | sort -V | tail -1)
fi

if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
    if [[ -z "$_latest" ]]; then
        echo "Claude Code not found and cannot reach download server." >&2
        exit 1
    fi
    echo "Downloading Claude Code $_latest..." >&2
    curl -fL --max-time 300 "$GCS/$_latest/$CLAUDE_PLATFORM/claude" -o "$CLAUDE_BIN"
    chmod +x "$CLAUDE_BIN"
fi

exec "$CLAUDE_BIN" \
    --dangerously-skip-permissions \
    --append-system-prompt "You are running inside a Docker container, not directly on the host machine. The current project directory is mounted from the host filesystem." \
    "$@"
