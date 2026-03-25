#!/usr/bin/env bash
# status.sh — Show the current state of the local LLM server
#
# Usage: status.sh
#
# Options:
#   -h, --help  Show this help message

set -euo pipefail

# ── Help ──────────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VRAM_TIERS="$PROJECT_DIR/models/vram-tiers.conf"

LLM_PORT="${LLM_PORT:-11434}"

# ── Read runtime state file ───────────────────────────────────────────────────
# Use grep (not source) to avoid executing arbitrary content.
STATE_FILE="$PROJECT_DIR/.llm-state"
STATE_BACKEND=""
STATE_VRAM_TIER=""
STATE_VRAM_DESC=""

if [[ -f "$STATE_FILE" ]]; then
  STATE_BACKEND="$(grep '^backend=' "$STATE_FILE" | cut -d= -f2)"
  STATE_VRAM_TIER="$(grep '^vram_tier=' "$STATE_FILE" | cut -d= -f2 || true)"

  # Look up tier description from vram-tiers.conf
  if [[ -n "$STATE_VRAM_TIER" && -f "$VRAM_TIERS" ]]; then
    STATE_VRAM_DESC="$(awk -F'|' -v t="$STATE_VRAM_TIER" '!/^#/ && !/^$/ && $1 == t {print $6; exit}' "$VRAM_TIERS" 2>/dev/null || true)"
  fi
fi

# ── Check if container is running ────────────────────────────────────────────
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^llm-server$"; then
  echo "INFO: No LLM server is currently running."
  echo "      Start one with: ./scripts/provision.sh -m glm-4"
  exit 0
fi

# ── Gather container info ─────────────────────────────────────────────────────
CONTAINER_STATUS="$(docker inspect llm-server --format '{{.State.Status}}' 2>/dev/null || echo 'unknown')"
CONTAINER_STARTED="$(docker inspect llm-server --format '{{.State.StartedAt}}' 2>/dev/null || echo '')"

# Calculate uptime
UPTIME_STR="unknown"
if [[ -n "$CONTAINER_STARTED" ]] && command -v python3 &>/dev/null; then
  UPTIME_STR="$(python3 -c "
from datetime import datetime, timezone
import sys
started = '$CONTAINER_STARTED'
try:
    # Docker uses RFC3339 with nanoseconds, truncate to seconds
    started = started[:19] + 'Z' if 'T' in started else started
    if started.endswith('Z'):
        started = started[:-1] + '+00:00'
    dt = datetime.fromisoformat(started)
    now = datetime.now(timezone.utc)
    diff = now - dt
    hours, rem = divmod(int(diff.total_seconds()), 3600)
    minutes = rem // 60
    if hours > 0:
        print(f'{hours}h {minutes}m')
    else:
        print(f'{minutes}m')
except Exception:
    print('unknown')
" 2>/dev/null || echo 'unknown')"
fi

# Resource usage (non-streaming docker stats snapshot)
CPU_PCT="n/a"
MEM_USAGE="n/a"
if STATS="$(docker stats llm-server --no-stream --format '{{.CPUPerc}}|{{.MemUsage}}' 2>/dev/null)"; then
  CPU_PCT="$(echo "$STATS" | awk -F'|' '{print $1}')"
  MEM_USAGE="$(echo "$STATS" | awk -F'|' '{print $2}')"
fi

# Loaded model name from API
MODEL_ID="(server warming up)"
if API_RESP="$(curl -sf "http://localhost:${LLM_PORT}/v1/models" 2>/dev/null)"; then
  if command -v python3 &>/dev/null; then
    MODEL_ID="$(echo "$API_RESP" | python3 -c "
import json,sys
data=json.load(sys.stdin)
models=data.get('data',[])
if models:
    print(models[0].get('id','unknown'))
else:
    print('(no model loaded)')
" 2>/dev/null || echo 'unknown')"
  else
    # Fallback: crude grep
    MODEL_ID="$(echo "$API_RESP" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"//;s/"//' || echo 'unknown')"
  fi
fi

# GPU info (if nvidia-smi available)
GPU_INFO=""
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  if GPU_RAW="$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)"; then
    USED="$(echo "$GPU_RAW" | awk -F',' '{print $1}' | tr -d ' ')"
    TOTAL="$(echo "$GPU_RAW" | awk -F',' '{print $2}' | tr -d ' ')"
    GPU_INFO="${USED} MiB / ${TOTAL} MiB"
  fi
fi

# ── Display ───────────────────────────────────────────────────────────────────
LINE="═══════════════════════════════════════════════════════"
echo "╔${LINE}╗"
printf "║  %-20s %-34s║\n" "Model:"     "$MODEL_ID"

# Show backend and VRAM tier when state file is present
if [[ -n "$STATE_BACKEND" ]]; then
  printf "║  %-20s %-34s║\n" "Backend:"   "$STATE_BACKEND"
  if [[ -n "$STATE_VRAM_TIER" ]]; then
    TIER_DISPLAY="${STATE_VRAM_TIER}"
    if [[ -n "$STATE_VRAM_DESC" ]]; then
      TIER_DISPLAY="${STATE_VRAM_TIER} — ${STATE_VRAM_DESC}"
    fi
    printf "║  %-20s %-34s║\n" "VRAM Tier:" "$TIER_DISPLAY"
  fi
fi

printf "║  %-20s %-34s║\n" "Port:"      "$LLM_PORT"
printf "║  %-20s %-34s║\n" "Endpoint:"  "http://localhost:${LLM_PORT}/v1"
printf "║  %-20s %-34s║\n" "Uptime:"    "$UPTIME_STR"
printf "║  %-20s %-34s║\n" "Container:" "llm-server ($CONTAINER_STATUS)"
printf "║  %-20s %-34s║\n" "CPU:"       "$CPU_PCT"
printf "║  %-20s %-34s║\n" "Memory:"    "$MEM_USAGE"
if [[ -n "$GPU_INFO" ]]; then
  printf "║  %-20s %-34s║\n" "GPU VRAM:"  "$GPU_INFO"
fi
echo "╚${LINE}╝"
