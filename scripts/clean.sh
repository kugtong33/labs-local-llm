#!/usr/bin/env bash
# clean.sh — Stop and remove the local LLM inference server
#
# Usage: clean.sh [--keep-models | --purge-models]
#
# Options:
#   --keep-models   Stop containers but preserve downloaded model weights (default)
#   --purge-models  Stop containers AND delete the model volume (frees disk space)
#   -h, --help      Show this help message
#
# Note: --purge-models is irreversible and will delete all downloaded model weights.
#       Re-provisioning will re-download models (may take significant time/bandwidth).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Defaults ──────────────────────────────────────────────────────────────────
PURGE_MODELS=false

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --keep-models)  PURGE_MODELS=false ;;
    --purge-models) PURGE_MODELS=true ;;
    -h|--help)      usage ;;
    *)
      echo "ERROR: Unknown option '$arg'. Use -h for help." >&2
      exit 1
      ;;
  esac
done

# ── Check Docker ──────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed or not in PATH." >&2
  exit 1
fi

# ── Check if anything is running ──────────────────────────────────────────────
LLM_PORT="${LLM_PORT:-11434}"
GPU_DEVICE_ID="${GPU_DEVICE_ID:-0}"
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-/opt/llm-models}"

CONTAINER_RUNNING=false
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^llm-server$"; then
  CONTAINER_RUNNING=true
fi

if [[ "$CONTAINER_RUNNING" == "false" ]]; then
  echo "INFO: No LLM server is currently running."
fi

# ── Stop containers ───────────────────────────────────────────────────────────
echo "INFO: Stopping LLM server..."

if [[ "$PURGE_MODELS" == "true" ]]; then
  (cd "$PROJECT_DIR" && \
    MODEL_CACHE_DIR="$MODEL_CACHE_DIR" LLM_PORT="$LLM_PORT" GPU_DEVICE_ID="$GPU_DEVICE_ID" \
    docker compose --profile gpu --profile cpu down --volumes --remove-orphans 2>/dev/null) || true
else
  (cd "$PROJECT_DIR" && \
    MODEL_CACHE_DIR="$MODEL_CACHE_DIR" LLM_PORT="$LLM_PORT" GPU_DEVICE_ID="$GPU_DEVICE_ID" \
    docker compose --profile gpu --profile cpu down --remove-orphans 2>/dev/null) || true
fi

# ── Report ────────────────────────────────────────────────────────────────────
if [[ "$CONTAINER_RUNNING" == "true" ]]; then
  echo "INFO: Container llm-server stopped and removed."
fi

if [[ "$PURGE_MODELS" == "true" ]]; then
  # Also remove the named volume explicitly in case compose didn't catch it
  docker volume rm llm-model-cache 2>/dev/null || true
  echo "INFO: Model volume removed. All downloaded weights have been deleted."
  echo "      Re-provision to re-download: ./scripts/provision.sh -m <model>"
else
  echo "INFO: Model volume preserved (use --purge-models to delete downloaded weights)."
fi

echo ""
echo "✓ Clean complete."
