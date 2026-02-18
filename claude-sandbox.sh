#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
CONTAINER_NAME="claude-sandbox"
IMAGE_NAME="claude-sandbox:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.claude"
WORK_DIR="$(pwd)"

# Auto-detect latest claude binary
CLAUDE_VERSIONS_DIR="$HOME/.local/share/claude/versions"
CLAUDE_BINARY=""
if [[ -d "$CLAUDE_VERSIONS_DIR" ]]; then
    CLAUDE_BINARY="$CLAUDE_VERSIONS_DIR/$(ls -1 "$CLAUDE_VERSIONS_DIR" | sort -V | tail -1)"
fi

if [[ -z "$CLAUDE_BINARY" || ! -f "$CLAUDE_BINARY" ]]; then
    echo "Error: Could not find claude binary under $CLAUDE_VERSIONS_DIR" >&2
    exit 1
fi

# --- Helper functions ---

ensure_image() {
    if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
        echo "Building $IMAGE_NAME..." >&2
        docker build \
            --build-arg USER_NAME="$(whoami)" \
            --build-arg USER_UID="$(id -u)" \
            --build-arg USER_GID="$(id -g)" \
            -t "$IMAGE_NAME" \
            "$SCRIPT_DIR"
    fi
}

ensure_container() {
    ensure_image

    local state
    state="$(docker container inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)"
    state="${state//[$'\t\r\n ']/}"
    [[ -z "$state" ]] && state="missing"

    case "$state" in
        running)
            # Already running, nothing to do
            ;;
        exited|created)
            echo "Starting existing container $CONTAINER_NAME..." >&2
            docker start "$CONTAINER_NAME" >/dev/null
            ;;
        missing)
            echo "Creating container $CONTAINER_NAME..." >&2
            docker run -d \
                --name "$CONTAINER_NAME" \
                --network host \
                -v "$CONFIG_DIR:$CONFIG_DIR" \
                -v "$HOME:$HOME" \
                -v "$CLAUDE_BINARY:/usr/local/bin/claude:ro" \
                "$IMAGE_NAME" >/dev/null
            ;;
        *)
            echo "Container $CONTAINER_NAME is in unexpected state: $state. Removing and recreating..." >&2
            docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
            docker run -d \
                --name "$CONTAINER_NAME" \
                --network host \
                -v "$CONFIG_DIR:$CONFIG_DIR" \
                -v "$HOME:$HOME" \
                -v "$CLAUDE_BINARY:/usr/local/bin/claude:ro" \
                "$IMAGE_NAME" >/dev/null
            ;;
    esac
}

sandbox_rebuild() {
    echo "Rebuilding $IMAGE_NAME..." >&2
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
    docker build \
        --build-arg USER_NAME="$(whoami)" \
        --build-arg USER_UID="$(id -u)" \
        --build-arg USER_GID="$(id -g)" \
        --no-cache \
        -t "$IMAGE_NAME" \
        "$SCRIPT_DIR"
    echo "Rebuild complete." >&2
}

sandbox_stop() {
    if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
        docker stop "$CONTAINER_NAME" >/dev/null
        echo "Container $CONTAINER_NAME stopped." >&2
    else
        echo "No container found." >&2
    fi
}

sandbox_status() {
    local state
    state="$(docker container inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "")"
    if [[ -z "$state" ]]; then
        echo "No container found."
    else
        echo "Container is $state."
    fi
}

# --- Main ---

case "${1:-}" in
    --sandbox-rebuild)
        sandbox_rebuild
        exit 0
        ;;
    --sandbox-stop)
        sandbox_stop
        exit 0
        ;;
    --sandbox-status)
        sandbox_status
        exit 0
        ;;
esac

ensure_container

# Build docker exec flags
EXEC_FLAGS=()
if [[ -t 0 && -t 1 ]]; then
    EXEC_FLAGS+=(-it)
elif [[ -t 0 || -t 1 ]]; then
    EXEC_FLAGS+=(-i)
fi
EXEC_FLAGS+=(-w "$WORK_DIR")
EXEC_FLAGS+=(-e "CLAUDECODE=")
EXEC_FLAGS+=(-e "HOME=$HOME")
EXEC_FLAGS+=(-e "PATH=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
[[ -n "${ANTHROPIC_API_KEY:-}" ]] && EXEC_FLAGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")

exec docker exec \
    "${EXEC_FLAGS[@]}" \
    "$CONTAINER_NAME" \
    claude --dangerously-skip-permissions "$@"
