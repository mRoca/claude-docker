#!/usr/bin/env bash
# xclip shim installed ahead of /usr/bin/xclip.
#
# On macOS hosts there is no X11/Wayland socket to forward, so the claude-docker
# wrapper runs a small bridge on the host and points CLAUDE_DOCKER_CLIPBOARD_DIR
# at a directory shared with it. Image reads are relayed through that directory:
#   container writes <id>.req -> host answers with <id>.png (or <id>.none)
# Without that variable, this defers to the real xclip (Linux hosts).
set -u

dir="${CLAUDE_DOCKER_CLIPBOARD_DIR:-}"
# Linux host (no bridge, var unset) or bridge dir missing: defer to the real
# xclip, which uses the forwarded X11/Wayland socket.
if [[ -z "$dir" || ! -d "$dir" ]]; then
    exec /usr/bin/xclip "$@"
fi

target=""
output=false
while (($#)); do
    case "$1" in
        -t|-target) target="${2:-}"; shift ;;
        -o|-out) output=true ;;
    esac
    shift
done

# Only clipboard image reads are bridged; text paste goes through the terminal
$output || exit 1

fetch_image() {
    local id="$$-$RANDOM"
    : > "$dir/$id.req"
    for _ in $(seq 50); do
        if [[ -f "$dir/$id.png" ]]; then
            cat "$dir/$id.png"
            rm -f "$dir/$id.png"
            return 0
        fi
        if [[ -f "$dir/$id.none" ]]; then
            rm -f "$dir/$id.none"
            return 1
        fi
        sleep 0.1
    done
    rm -f "$dir/$id.req"
    return 1
}

# Claude Code reads TARGETS then image/png, so PNG is all it needs. macOS converts
# any clipboard image to PNG. Text is never relayed: the terminal pastes it.
case "$target" in
    TARGETS)   fetch_image >/dev/null && echo "image/png" ;;
    image/png) fetch_image ;;
    *)         exit 1 ;;
esac
