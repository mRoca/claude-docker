#!/usr/bin/env bash
set -euo pipefail

# Same download endpoint as https://claude.ai/install.sh
DOWNLOAD_BASE_URL="https://downloads.claude.ai/claude-code-releases"

VERSIONS_DIR="$HOME/.claude/docker/versions"
mkdir -p "$VERSIONS_DIR"

case "$(uname -m)" in
    x86_64)  CLAUDE_PLATFORM="linux-x64" ;;
    aarch64) CLAUDE_PLATFORM="linux-arm64" ;;
    *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

_latest=$(curl -sf --connect-timeout 2 --max-time 3 "$DOWNLOAD_BASE_URL/latest" 2>/dev/null || true)
# Reject anything that isn't a version string (e.g. an HTML error page)
[[ "$_latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$ ]] || _latest=""

if [[ -n "$_latest" ]]; then
    CLAUDE_BIN="$VERSIONS_DIR/$_latest"
else
    # Offline fallback: use the most recently downloaded version
    CLAUDE_BIN=$(find "$VERSIONS_DIR" -maxdepth 1 -type f -perm -u+x | sort -V | tail -1)
fi

if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
    if [[ -z "$_latest" ]]; then
        echo "Claude Code not found and cannot reach download server." >&2
        exit 1
    fi
    echo "Downloading Claude Code $_latest..." >&2
    _expected=$(curl -fsSL --max-time 30 "$DOWNLOAD_BASE_URL/$_latest/manifest.json" \
        | jq -r --arg p "$CLAUDE_PLATFORM" '.platforms[$p].checksum // empty')
    _tmp="$CLAUDE_BIN.part.$$"
    trap 'rm -f "$_tmp"' EXIT
    curl -fL --max-time 300 "$DOWNLOAD_BASE_URL/$_latest/$CLAUDE_PLATFORM/claude" -o "$_tmp"
    if [[ -z "$_expected" || "$(sha256sum "$_tmp" | cut -d' ' -f1)" != "$_expected" ]]; then
        echo "Checksum verification failed for Claude Code $_latest." >&2
        exit 1
    fi
    chmod +x "$_tmp"
    mv "$_tmp" "$CLAUDE_BIN"
    trap - EXIT
fi

# --strict-mcp-config disables MCP auto-discovery. Required because claude.ai-managed
# remote MCP servers (Notion, Slack, etc.) need OAuth tokens from the host keychain,
# which the container can't reach — without this, claude exits silently at startup.
exec "$CLAUDE_BIN" \
    --dangerously-skip-permissions \
    --strict-mcp-config \
    --append-system-prompt "You are running inside a Docker container, not directly on the host machine. The current project directory is mounted from the host filesystem." \
    "$@"
