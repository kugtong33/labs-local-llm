#!/usr/bin/env bash
# provision.sh — Start a local LLM inference server
#
# Usage: provision.sh -m MODEL [-M MODE] [-p PORT] [-g GPU_ID]
#
# Options:
#   -m MODEL   Model to run (required). See models/registry.conf for supported values.
#   -M MODE    Hardware mode: gpu | cpu | auto (default: auto)
#   -p PORT    Host port to bind (default: 11434)
#   -g GPU_ID  NVIDIA GPU device index (default: 0, GPU mode only)
#   -h         Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REGISTRY="$PROJECT_DIR/models/registry.conf"
MODELFILE_DIR="$PROJECT_DIR/models"

# ── Defaults ──────────────────────────────────────────────────────────────────
MODEL_NAME=""
MODE="auto"
LLM_PORT="${LLM_PORT:-11434}"
GPU_DEVICE_ID="${GPU_DEVICE_ID:-0}"

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts "m:M:p:g:h" opt; do
  case $opt in
    m) MODEL_NAME="$OPTARG" ;;
    M) MODE="$OPTARG" ;;
    p) LLM_PORT="$OPTARG" ;;
    g) GPU_DEVICE_ID="$OPTARG" ;;
    h) usage ;;
    *) echo "ERROR: Unknown flag. Use -h for help." >&2; exit 1 ;;
  esac
done

# ── Validation: model name required ──────────────────────────────────────────
if [[ -z "$MODEL_NAME" ]]; then
  echo "ERROR: -m MODEL is required." >&2
  echo "       Supported models: $(get_supported_ids 2>/dev/null || awk -F'|' 'NF>=1 && !/^#/ && !/^$/ {printf "%s ", $1}' "$REGISTRY" 2>/dev/null)" >&2
  echo "       Use -h for full usage." >&2
  exit 1
fi

# ── Registry helpers ──────────────────────────────────────────────────────────
# Returns registry line for a model id, or empty string
lookup_model() {
  local id="$1"
  awk -F'|' -v id="$id" '!/^#/ && !/^$/ && $1 == id {print; exit}' "$REGISTRY" 2>/dev/null || true
}

get_supported_ids() {
  awk -F'|' '!/^#/ && !/^$/ && NF>=1 {printf "%s ", $1}' "$REGISTRY" 2>/dev/null
}

# ── Validation: model must exist in registry ─────────────────────────────────
if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: Model registry not found at $REGISTRY" >&2
  exit 1
fi

REGISTRY_LINE="$(lookup_model "$MODEL_NAME")"
if [[ -z "$REGISTRY_LINE" ]]; then
  echo "ERROR: Unsupported model '$MODEL_NAME'." >&2
  echo "       Supported models: $(get_supported_ids)" >&2
  exit 1
fi

OLLAMA_ID="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $2}')"
MODEL_STATUS="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $5}')"
MIN_VRAM="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $3}')"
MIN_RAM="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $4}')"

if [[ "$MODEL_STATUS" == "experimental" ]]; then
  echo "WARNING: '$MODEL_NAME' is an experimental model. Stability is not guaranteed." >&2
  echo "         See models/minimax-m1.Modelfile for setup requirements." >&2
fi

# ── Validation: mode flag ─────────────────────────────────────────────────────
if [[ "$MODE" != "gpu" && "$MODE" != "cpu" && "$MODE" != "auto" ]]; then
  echo "ERROR: Invalid mode '$MODE'. Must be: gpu, cpu, or auto." >&2
  exit 1
fi

# ── Validation: Docker available ─────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed or not in PATH." >&2
  echo "       Install Docker Engine: https://docs.docker.com/engine/install/" >&2
  exit 2
fi

if ! docker info &>/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running." >&2
  echo "       Start it with: sudo systemctl start docker" >&2
  exit 2
fi

if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null 2>&1; then
  if ! docker-compose version &>/dev/null 2>&1; then
    echo "ERROR: Docker Compose v2 is required but not found." >&2
    echo "       Install: https://docs.docker.com/compose/install/" >&2
    exit 2
  fi
fi

# ── Validation: port availability ────────────────────────────────────────────
if command -v lsof &>/dev/null; then
  if lsof -iTCP:"$LLM_PORT" -sTCP:LISTEN -t &>/dev/null 2>&1; then
    echo "ERROR: Port $LLM_PORT is already in use." >&2
    echo "       Use -p to specify a different port (e.g., -p 11435)." >&2
    exit 3
  fi
elif command -v ss &>/dev/null; then
  if ss -tlnp | grep -q ":$LLM_PORT "; then
    echo "ERROR: Port $LLM_PORT is already in use." >&2
    echo "       Use -p to specify a different port (e.g., -p 11435)." >&2
    exit 3
  fi
fi

# ── GPU detection ─────────────────────────────────────────────────────────────
detect_gpu() {
  # Step 1: nvidia-smi must be available and functional
  if ! command -v nvidia-smi &>/dev/null || ! nvidia-smi &>/dev/null 2>&1; then
    return 1
  fi
  # Step 2: NVIDIA Container Toolkit must be registered with Docker
  if ! docker info 2>/dev/null | grep -qi "nvidia"; then
    echo "WARNING: nvidia-smi found but NVIDIA Container Toolkit is not registered with Docker." >&2
    echo "         Fix: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker" >&2
    return 1
  fi
  return 0
}

RESOLVED_MODE="$MODE"
if [[ "$MODE" == "auto" ]]; then
  if detect_gpu; then
    RESOLVED_MODE="gpu"
    echo "INFO: GPU detected — running in GPU mode (device $GPU_DEVICE_ID)."
  else
    RESOLVED_MODE="cpu"
    echo "INFO: No GPU available — running in CPU mode."
    echo "      Hardware requirements for ${MODEL_NAME} on CPU: ${MIN_RAM} GB RAM"
  fi
elif [[ "$MODE" == "gpu" ]]; then
  if ! detect_gpu; then
    echo "ERROR: GPU mode requested but GPU prerequisites are not met." >&2
    echo "       Requires: NVIDIA GPU + NVIDIA Container Toolkit registered with Docker." >&2
    echo "       See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html" >&2
    exit 4
  fi
  echo "INFO: GPU mode (device $GPU_DEVICE_ID). Min VRAM required: ${MIN_VRAM} GB"
else
  echo "INFO: CPU mode. Min RAM required: ${MIN_RAM} GB"
fi

# ── Ensure MODEL_CACHE_DIR exists ─────────────────────────────────────────────
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-/opt/llm-models}"
if [[ ! -d "$MODEL_CACHE_DIR" ]]; then
  echo "INFO: Creating model cache directory: $MODEL_CACHE_DIR"
  mkdir -p "$MODEL_CACHE_DIR" || {
    echo "ERROR: Cannot create $MODEL_CACHE_DIR. Try: sudo mkdir -p $MODEL_CACHE_DIR && sudo chown $USER $MODEL_CACHE_DIR" >&2
    exit 1
  }
fi

# ── MiniMax-M1 GGUF prerequisite check ───────────────────────────────────────
if [[ "$MODEL_NAME" == "minimax-m1" ]]; then
  GGUF_PATH="$MODEL_CACHE_DIR/minimax-m1.gguf"
  if [[ ! -f "$GGUF_PATH" ]]; then
    echo "ERROR: MiniMax-M1 GGUF file not found at $GGUF_PATH" >&2
    echo "       Download a GGUF conversion (e.g., from https://huggingface.co/bartowski)" >&2
    echo "       and place it at: $GGUF_PATH" >&2
    exit 1
  fi
fi

# ── Stop any existing instance ────────────────────────────────────────────────
echo "INFO: Stopping any existing LLM server..."
(cd "$PROJECT_DIR" && \
  MODEL_CACHE_DIR="$MODEL_CACHE_DIR" LLM_PORT="$LLM_PORT" GPU_DEVICE_ID="$GPU_DEVICE_ID" \
  docker compose --profile gpu --profile cpu down --remove-orphans 2>/dev/null) || true

# ── Start the container ───────────────────────────────────────────────────────
echo "INFO: Starting $MODEL_NAME (mode: $RESOLVED_MODE) on port $LLM_PORT..."
echo "      This may take several minutes on first run while the model downloads."
echo ""

export MODEL_CACHE_DIR LLM_PORT GPU_DEVICE_ID

(cd "$PROJECT_DIR" && docker compose --profile "$RESOLVED_MODE" up -d --pull always)

# ── Wait for health check ─────────────────────────────────────────────────────
echo ""
echo "INFO: Waiting for server to be ready (up to 3 minutes)..."
MAX_WAIT=180
ELAPSED=0
while [[ $ELAPSED -lt $MAX_WAIT ]]; do
  if curl -sf "http://localhost:${LLM_PORT}/" &>/dev/null; then
    break
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  printf "."
done
printf "\n"

if ! curl -sf "http://localhost:${LLM_PORT}/" &>/dev/null; then
  echo "ERROR: Server did not become ready within ${MAX_WAIT}s." >&2
  echo "       Check logs: docker compose logs llm-${RESOLVED_MODE}" >&2
  exit 1
fi

# ── Pull / register the model in Ollama ───────────────────────────────────────
echo "INFO: Loading model '$OLLAMA_ID' into Ollama..."

if [[ "$MODEL_NAME" == "minimax-m1" ]]; then
  echo "INFO: [EXPERIMENTAL] Importing MiniMax-M1 from GGUF file..."
  docker cp "$MODELFILE_DIR/minimax-m1.Modelfile" llm-server:/tmp/minimax-m1.Modelfile
  docker exec llm-server ollama create minimax-m1 -f /tmp/minimax-m1.Modelfile
else
  docker exec llm-server ollama pull "$OLLAMA_ID"
fi

# ── Success ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ LLM server is ready"
echo ""
echo "  Model:         $MODEL_NAME ($OLLAMA_ID)"
echo "  Mode:          $RESOLVED_MODE"
echo "  API endpoint:  http://localhost:${LLM_PORT}/v1"
echo "  Models list:   http://localhost:${LLM_PORT}/v1/models"
echo ""
echo "  Monitor logs:  docker compose logs -f"
echo "  Check status:  ./scripts/status.sh"
echo "  Stop server:   ./scripts/clean.sh"
