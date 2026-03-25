# Contract: Shell Script CLI Interface

**Feature**: `001-local-llm-coding-setup`
**Date**: 2026-03-25
**Type**: CLI (shell scripts)

These are the public interfaces for the four management scripts. All scripts print usage with `-h` or `--help`.

---

## `scripts/provision.sh`

Start a local LLM inference server.

### Synopsis

```
provision.sh -m MODEL [-M MODE] [-p PORT] [-g GPU_ID]
```

### Options

| Flag | Long form | Required | Default | Description |
|---|---|---|---|---|
| `-m MODEL` | `--model MODEL` | Yes | — | Model to run. One of: `deepseek-v3`, `glm-4`, `minimax-m1` |
| `-M MODE` | `--mode MODE` | No | `auto` | Hardware mode: `gpu`, `cpu`, or `auto` |
| `-p PORT` | `--port PORT` | No | `11434` | Host port to bind the inference server |
| `-g GPU_ID` | `--gpu GPU_ID` | No | `0` | NVIDIA GPU device index (GPU mode only) |
| `-h` | `--help` | No | — | Print usage and exit |

### Behavior

1. Validates model name against the supported registry
2. Validates Docker is installed and daemon is running
3. Checks port availability
4. Resolves hardware mode (auto-detects GPU if `auto`)
5. Stops any running `llm-server` container
6. Starts the container with the selected model and mode
7. Prints the API endpoint URL on success

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Server started successfully |
| 1 | Invalid argument or validation failure |
| 2 | Docker not available |
| 3 | Port already in use |
| 4 | GPU mode requested but prerequisites not met |

### Examples

```bash
# Auto-detect GPU, use GLM-4
./scripts/provision.sh -m glm-4

# Force CPU mode, custom port
./scripts/provision.sh -m deepseek-v3 -M cpu -p 8080

# GPU mode, second GPU device
./scripts/provision.sh -m glm-4 -M gpu -g 1
```

### Stdout contract

On success, prints:
```
INFO: Starting glm-4 (mode: gpu) on port 11434...
SUCCESS: LLM server is ready
  API endpoint:  http://localhost:11434/v1
  Models list:   http://localhost:11434/v1/models
  Logs:          docker compose logs -f
  Status:        ./scripts/status.sh
```

---

## `scripts/clean.sh`

Stop and remove the LLM inference server.

### Synopsis

```
clean.sh [--keep-models | --purge-models]
```

### Options

| Flag | Default | Description |
|---|---|---|
| `--keep-models` | Yes (default) | Stop containers but preserve the model volume |
| `--purge-models` | — | Stop containers AND remove the model volume (irreversible) |
| `-h`, `--help` | — | Print usage and exit |

### Behavior

1. Stops the running `llm-server` container
2. Removes the container and Docker network
3. If `--purge-models`: also removes the `llm-model-cache` Docker volume
4. Prints a summary of what was removed

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Clean completed successfully (or nothing was running) |
| 1 | Unexpected error |

### Examples

```bash
# Stop server, keep downloaded models (safe default)
./scripts/clean.sh

# Stop server AND delete all model weights (~5-200 GB freed)
./scripts/clean.sh --purge-models
```

### Stdout contract

```
INFO: Stopping LLM server...
INFO: Container llm-server stopped and removed.
INFO: Model volume preserved (use --purge-models to delete).
SUCCESS: Clean complete.
```

---

## `scripts/update.sh`

Pull the latest version of a model and restart the server.

### Synopsis

```
update.sh -m MODEL [-M MODE] [-p PORT]
```

### Options

| Flag | Required | Default | Description |
|---|---|---|---|
| `-m MODEL` | Yes | — | Model to update. One of: `deepseek-v3`, `glm-4`, `minimax-m1` |
| `-M MODE` | No | Same as current / `auto` | Hardware mode after restart |
| `-p PORT` | No | `11434` | Port to bind after restart |
| `-h` | No | — | Print usage and exit |

### Behavior

1. Validates model name
2. Pulls the latest model version via `ollama pull`
3. Restarts the server with the updated model
4. Prints the result

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Update successful |
| 1 | Invalid argument |
| 2 | Docker not available |
| 3 | Pull failed (network error or model not found) |

### Examples

```bash
# Update GLM-4 to latest version
./scripts/update.sh -m glm-4

# Update and restart in CPU mode
./scripts/update.sh -m glm-4 -M cpu
```

---

## `scripts/status.sh`

Show the current state of the local LLM setup.

### Synopsis

```
status.sh
```

### Options

| Flag | Description |
|---|---|
| `-h`, `--help` | Print usage and exit |

### Behavior

Queries Docker for the current state of `llm-server` and prints:
- Running container name and uptime
- Loaded model name (via `/v1/models` API call)
- Hardware mode (GPU or CPU)
- Host port and API endpoint
- Docker resource usage (CPU %, memory usage)
- GPU utilization (if GPU mode, via `nvidia-smi`)

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Status printed (even if server is not running) |
| 1 | Error querying status |

### Stdout contract

When server is running:
```
╔══ LLM Server Status ══════════════════════════════════════╗
║  Model:     glm4:latest                                   ║
║  Mode:      gpu (device 0)                                ║
║  Port:      11434                                         ║
║  Endpoint:  http://localhost:11434/v1                     ║
║  Uptime:    2 hours, 14 minutes                           ║
║  Container: llm-server (Up)                               ║
║  CPU:       12.3%   Memory: 6.2 GB / 32 GB               ║
║  GPU VRAM:  7.8 GB / 24 GB                                ║
╚═══════════════════════════════════════════════════════════╝
```

When server is not running:
```
INFO: No LLM server is currently running.
      Start one with: ./scripts/provision.sh -m glm-4
```

---

## Common Error Messages

All scripts produce error messages in this format:

```
ERROR: <description of problem>
       <suggested fix or next step>
```

| Error | Example message |
|---|---|
| Invalid model | `ERROR: Unsupported model 'foo'. Supported: deepseek-v3, glm-4, minimax-m1` |
| Docker not installed | `ERROR: Docker is not installed. Install Docker Desktop or Docker Engine.` |
| Docker not running | `ERROR: Docker daemon is not running. Start it with: sudo systemctl start docker` |
| Port in use | `ERROR: Port 11434 is already in use. Use -p to specify a different port.` |
| GPU prerequisites missing | `ERROR: GPU mode requires NVIDIA Container Toolkit. See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html` |
