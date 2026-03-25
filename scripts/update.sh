#!/usr/bin/env bash
# update.sh — Pull the latest version of a model and restart the server
#
# Usage: update.sh -m MODEL [-M MODE] [-p PORT]
#
# Options:
#   -m MODEL  Model to update (required). See models/registry.conf for supported values.
#   -M MODE   Hardware mode after restart: gpu | cpu | auto (default: auto)
#   -p PORT   Host port to bind after restart (default: 11434)
#   -h        Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REGISTRY="$PROJECT_DIR/models/registry.conf"

# ── Defaults ──────────────────────────────────────────────────────────────────
MODEL_NAME=""
MODE="auto"
LLM_PORT="${LLM_PORT:-11434}"

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts "m:M:p:h" opt; do
  case $opt in
    m) MODEL_NAME="$OPTARG" ;;
    M) MODE="$OPTARG" ;;
    p) LLM_PORT="$OPTARG" ;;
    h) usage ;;
    *) echo "ERROR: Unknown flag. Use -h for help." >&2; exit 1 ;;
  esac
done

# ── Validation: model required ────────────────────────────────────────────────
if [[ -z "$MODEL_NAME" ]]; then
  echo "ERROR: -m MODEL is required." >&2
  echo "       Use -h for full usage." >&2
  exit 1
fi

# ── Validation: model in registry ────────────────────────────────────────────
REGISTRY_LINE="$(awk -F'|' -v id="$MODEL_NAME" '!/^#/ && !/^$/ && $1 == id {print; exit}' "$REGISTRY" 2>/dev/null || true)"
if [[ -z "$REGISTRY_LINE" ]]; then
  SUPPORTED="$(awk -F'|' '!/^#/ && !/^$/ && NF>=1 {printf "%s ", $1}' "$REGISTRY" 2>/dev/null)"
  echo "ERROR: Unsupported model '$MODEL_NAME'." >&2
  echo "       Supported models: $SUPPORTED" >&2
  exit 1
fi

OLLAMA_ID="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $2}')"

# ── Check Docker ──────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null || ! docker info &>/dev/null 2>&1; then
  echo "ERROR: Docker is not available. Ensure Docker is installed and running." >&2
  exit 2
fi

# ── Check if server is running ────────────────────────────────────────────────
SERVER_RUNNING=false
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^llm-server$"; then
  SERVER_RUNNING=true
fi

# ── Pull latest model ─────────────────────────────────────────────────────────
if [[ "$SERVER_RUNNING" == "true" ]]; then
  echo "INFO: Pulling latest version of '$OLLAMA_ID' inside running container..."
  if docker exec llm-server ollama pull "$OLLAMA_ID"; then
    echo "INFO: Model updated successfully."
    echo "INFO: Restarting server to apply update..."
    docker restart llm-server
    echo "✓ Update complete. Server restarted with latest $MODEL_NAME."
  else
    echo "ERROR: Failed to pull latest model '$OLLAMA_ID'." >&2
    echo "       Check network connectivity and try again." >&2
    exit 3
  fi
else
  echo "INFO: Server is not running. Provisioning with latest model..."
  "$SCRIPT_DIR/provision.sh" -m "$MODEL_NAME" -M "$MODE" -p "$LLM_PORT"
fi
