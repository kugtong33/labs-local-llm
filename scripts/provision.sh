#!/usr/bin/env bash
# provision.sh — Start a local LLM inference server
#
# Usage: provision.sh -m MODEL [-M MODE] [-p PORT] [-g GPU_ID] [-b BACKEND] [-V VRAM_TIER]
#
# Options:
#   -m MODEL      Model to run (required). See models/registry.conf for supported values.
#   -M MODE       Hardware mode: gpu | cpu | auto (default: auto)
#   -p PORT       Host port to bind (default: 11434)
#   -g GPU_ID     NVIDIA GPU device index (default: 0, GPU mode only)
#   -b BACKEND    Inference backend: ollama | llama.cpp (default: ollama)
#   -V VRAM_TIER  VRAM tier for llama.cpp: 8gb | 16gb | 24gb | 32gb (default: 8gb)
#                 Ignored when -b ollama. See models/vram-tiers.conf for parameter details.
#   -h            Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REGISTRY="$PROJECT_DIR/models/registry.conf"
VRAM_TIERS="$PROJECT_DIR/models/vram-tiers.conf"

# ── Defaults ──────────────────────────────────────────────────────────────────
MODEL_NAME=""
MODE="auto"
LLM_PORT="${LLM_PORT:-11434}"
GPU_DEVICE_ID="${GPU_DEVICE_ID:-0}"
BACKEND="ollama"
VRAM_TIER="8gb"

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
  grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while getopts "m:M:p:g:b:V:h" opt; do
  case $opt in
    m) MODEL_NAME="$OPTARG" ;;
    M) MODE="$OPTARG" ;;
    p) LLM_PORT="$OPTARG" ;;
    g) GPU_DEVICE_ID="$OPTARG" ;;
    b) BACKEND="$OPTARG" ;;
    V) VRAM_TIER="$OPTARG" ;;
    h) usage ;;
    *) echo "ERROR: Unknown flag. Use -h for help." >&2; exit 1 ;;
  esac
done

# ── Validation: model name required ──────────────────────────────────────────
if [[ -z "$MODEL_NAME" ]]; then
  echo "ERROR: -m MODEL is required." >&2
  echo "       Supported models: $(awk -F'|' '!/^#/ && !/^$/ && NF>=1 {printf "%s ", $1}' "$REGISTRY" 2>/dev/null)" >&2
  echo "       Use -h for full usage." >&2
  exit 1
fi

# ── Validation: backend flag ──────────────────────────────────────────────────
if [[ "$BACKEND" != "ollama" && "$BACKEND" != "llama.cpp" ]]; then
  echo "ERROR: Invalid backend '$BACKEND'. Must be: ollama or llama.cpp." >&2
  exit 1
fi

# ── Validation: VRAM tier flag (llama.cpp only) ───────────────────────────────
if [[ "$VRAM_TIER" != "8gb" && "$VRAM_TIER" != "16gb" && "$VRAM_TIER" != "24gb" && "$VRAM_TIER" != "32gb" ]]; then
  echo "ERROR: Invalid VRAM tier '$VRAM_TIER'. Must be: 8gb, 16gb, 24gb, or 32gb." >&2
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
# This check is backend-agnostic: applies to both ollama and llama.cpp.
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
GGUF_HF_REPO="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $6}')"
GGUF_FILENAME="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $7}')"
MIN_VRAM_TIER="$(echo "$REGISTRY_LINE" | awk -F'|' '{print $8}')"

if [[ "$MODEL_STATUS" == "experimental" ]]; then
  echo "WARNING: '$MODEL_NAME' is an experimental model. Stability is not guaranteed." >&2
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
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-${HOME}/.local/share/llm-models}"
if [[ ! -d "$MODEL_CACHE_DIR" ]]; then
  echo "INFO: Creating model cache directory: $MODEL_CACHE_DIR"
  mkdir -p "$MODEL_CACHE_DIR" || {
    echo "ERROR: Cannot create $MODEL_CACHE_DIR. Try: sudo mkdir -p $MODEL_CACHE_DIR && sudo chown $USER $MODEL_CACHE_DIR" >&2
    exit 1
  }
fi

# ── llama.cpp: VRAM tier lookup ───────────────────────────────────────────────
lookup_vram_tier() {
  local tier="$1"
  if [[ ! -f "$VRAM_TIERS" ]]; then
    echo "ERROR: VRAM tiers config not found at $VRAM_TIERS" >&2
    exit 1
  fi
  local line
  line="$(awk -F'|' -v t="$tier" '!/^#/ && !/^$/ && $1 == t {print; exit}' "$VRAM_TIERS" 2>/dev/null || true)"
  if [[ -z "$line" ]]; then
    echo "ERROR: VRAM tier '$tier' not found in $VRAM_TIERS" >&2
    exit 1
  fi
  echo "$line"
}

# Returns a numeric rank for tier comparison (lower = smaller tier)
tier_rank() {
  case "$1" in
    8gb)  echo 1 ;;
    16gb) echo 2 ;;
    24gb) echo 3 ;;
    32gb) echo 4 ;;
    *)    echo 0 ;;
  esac
}

if [[ "$BACKEND" == "llama.cpp" ]]; then
  TIER_LINE="$(lookup_vram_tier "$VRAM_TIER")"
  LLAMACPP_CTX_SIZE="$(echo "$TIER_LINE" | awk -F'|' '{print $2}')"
  LLAMACPP_N_GPU_LAYERS="$(echo "$TIER_LINE" | awk -F'|' '{print $3}')"
  LLAMACPP_BATCH_SIZE="$(echo "$TIER_LINE" | awk -F'|' '{print $4}')"
  LLAMACPP_UBATCH_SIZE="$(echo "$TIER_LINE" | awk -F'|' '{print $5}')"
  TIER_DESC="$(echo "$TIER_LINE" | awk -F'|' '{print $6}')"

  # Warn if selected tier is below the model's recommended minimum
  if [[ -n "$MIN_VRAM_TIER" ]]; then
    selected_rank="$(tier_rank "$VRAM_TIER")"
    min_rank="$(tier_rank "$MIN_VRAM_TIER")"
    if [[ "$selected_rank" -lt "$min_rank" ]]; then
      echo "WARNING: '$MODEL_NAME' recommends at least $MIN_VRAM_TIER VRAM tier." >&2
      echo "         Running on $VRAM_TIER may cause out-of-memory errors." >&2
    fi
  fi
fi

# ── llama.cpp: GGUF download ──────────────────────────────────────────────────
download_gguf() {
  local hf_repo="$1"
  local filename="$2"
  local cache_dir="$3"
  local dest="$cache_dir/$filename"

  if [[ "$hf_repo" == "local" ]]; then
    # User-provided GGUF — validate it exists, do not attempt download
    if [[ ! -f "$dest" ]]; then
      echo "ERROR: GGUF file not found at $dest" >&2
      echo "       This model requires a user-provided GGUF file." >&2
      echo "       Place the file at: $dest" >&2
      exit 1
    fi
    echo "INFO: Using local GGUF: $dest"
    return 0
  fi

  if [[ -f "$dest" ]]; then
    echo "INFO: GGUF already present, skipping download: $dest"
    return 0
  fi

  if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required to download GGUF files but was not found in PATH." >&2
    exit 1
  fi

  local url="https://huggingface.co/${hf_repo}/resolve/main/${filename}"
  echo "INFO: Downloading GGUF: $filename"
  echo "      Source: $url"
  echo "      Destination: $dest"
  echo "      (Download is resumable; re-run to continue if interrupted)"
  if ! curl -L -C - --progress-bar -o "$dest" "$url"; then
    echo "ERROR: Download failed. Check network connectivity and try again." >&2
    rm -f "$dest"
    exit 1
  fi
  echo "INFO: Download complete: $dest"
}

if [[ "$BACKEND" == "llama.cpp" ]]; then
  download_gguf "$GGUF_HF_REPO" "$GGUF_FILENAME" "$MODEL_CACHE_DIR"
fi

# ── Stop any existing instance ────────────────────────────────────────────────
echo "INFO: Stopping any existing LLM server..."
(cd "$PROJECT_DIR" && \
  MODEL_CACHE_DIR="$MODEL_CACHE_DIR" LLM_PORT="$LLM_PORT" GPU_DEVICE_ID="$GPU_DEVICE_ID" \
  docker compose --profile gpu --profile cpu \
    --profile llamacpp-gpu --profile llamacpp-cpu \
    down --remove-orphans 2>/dev/null) || true

# ── Start the container ───────────────────────────────────────────────────────
if [[ "$BACKEND" == "llama.cpp" ]]; then
  echo "INFO: Starting $MODEL_NAME via llama.cpp (mode: $RESOLVED_MODE, VRAM tier: $VRAM_TIER) on port $LLM_PORT..."
  echo "      Config: $TIER_DESC"
  echo "      Model file: $GGUF_FILENAME"
  echo "      This may take several minutes while the model loads into VRAM."
  echo ""

  export MODEL_CACHE_DIR LLM_PORT GPU_DEVICE_ID
  export LLAMACPP_MODEL_FILE="$GGUF_FILENAME"
  export LLAMACPP_CTX_SIZE LLAMACPP_N_GPU_LAYERS LLAMACPP_BATCH_SIZE LLAMACPP_UBATCH_SIZE

  (cd "$PROJECT_DIR" && docker compose --profile "llamacpp-${RESOLVED_MODE}" up -d --pull always)
else
  echo "INFO: Starting $MODEL_NAME (mode: $RESOLVED_MODE) on port $LLM_PORT..."
  echo "      This may take several minutes on first run while the model downloads."
  echo ""

  export MODEL_CACHE_DIR LLM_PORT GPU_DEVICE_ID

  (cd "$PROJECT_DIR" && docker compose --profile "$RESOLVED_MODE" up -d --pull always)
fi

# ── Wait for health check ─────────────────────────────────────────────────────
echo ""
echo "INFO: Waiting for server to be ready (up to 3 minutes)..."
MAX_WAIT=180
ELAPSED=0

# llama.cpp uses /v1/models (returns 200 only when model is loaded)
# Ollama uses / (returns 200 as soon as the daemon is up)
health_check() {
  if [[ "$BACKEND" == "llama.cpp" ]]; then
    curl -sf "http://localhost:${LLM_PORT}/v1/models" &>/dev/null
  else
    curl -sf "http://localhost:${LLM_PORT}/" &>/dev/null
  fi
}

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
  if health_check; then
    break
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  printf "."
done
printf "\n"

if ! health_check; then
  if [[ "$BACKEND" == "llama.cpp" ]]; then
    echo "ERROR: Server did not become ready within ${MAX_WAIT}s." >&2
    echo "       Check logs: docker compose logs llm-llamacpp-${RESOLVED_MODE}" >&2
  else
    echo "ERROR: Server did not become ready within ${MAX_WAIT}s." >&2
    echo "       Check logs: docker compose logs llm-${RESOLVED_MODE}" >&2
  fi
  exit 1
fi

# ── Pull / register the model ─────────────────────────────────────────────────
if [[ "$BACKEND" == "ollama" ]]; then
  echo "INFO: Loading model '$OLLAMA_ID' into Ollama..."

  docker exec llm-server ollama pull "$OLLAMA_ID"
fi
# llama.cpp: model is loaded directly from the GGUF file at container startup — no pull needed.

# ── Write runtime state file ──────────────────────────────────────────────────
STATE_FILE="$PROJECT_DIR/.llm-state"
STATE_TMP="${STATE_FILE}.tmp"

{
  echo "backend=$BACKEND"
  echo "model=$MODEL_NAME"
  echo "mode=$RESOLVED_MODE"
  echo "port=$LLM_PORT"
  if [[ "$BACKEND" == "llama.cpp" ]]; then
    echo "vram_tier=$VRAM_TIER"
    echo "model_file=$GGUF_FILENAME"
  fi
} > "$STATE_TMP"
mv "$STATE_TMP" "$STATE_FILE"

# ── Success ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ LLM server is ready"
echo ""
if [[ "$BACKEND" == "llama.cpp" ]]; then
  echo "  Model:         $MODEL_NAME ($GGUF_FILENAME)"
  echo "  Backend:       llama.cpp"
  echo "  VRAM Tier:     $VRAM_TIER ($TIER_DESC)"
  echo "  Mode:          $RESOLVED_MODE"
else
  echo "  Model:         $MODEL_NAME ($OLLAMA_ID)"
  echo "  Backend:       ollama"
  echo "  Mode:          $RESOLVED_MODE"
fi
echo "  API endpoint:  http://localhost:${LLM_PORT}/v1"
echo "  Models list:   http://localhost:${LLM_PORT}/v1/models"
echo ""
echo "  Monitor logs:  docker compose logs -f"
echo "  Check status:  ./scripts/status.sh"
echo "  Stop server:   ./scripts/clean.sh"
