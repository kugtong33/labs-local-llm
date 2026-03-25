# API Contract: OpenAI-Compatible Endpoint

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## Overview

Both the Ollama and llama.cpp backends expose an OpenAI-compatible REST API on `http://localhost:${LLM_PORT:-11434}/v1`. Clients configured for the Ollama backend require no changes when switching to llama.cpp.

## Endpoints

### GET /v1/models

Returns the list of loaded models. Used by clients to enumerate available models and by `status.sh` to read the active model name.

**Response** (both backends, `200 OK`):

```json
{
  "object": "list",
  "data": [
    {
      "id": "<model-id>",
      "object": "model",
      "created": 1704321600,
      "owned_by": "local"
    }
  ]
}
```

**Model ID differences between backends**:

| Backend | Example `id` value |
|---------|-------------------|
| Ollama | `glm4:latest` |
| llama.cpp | `glm-4-9b-chat-Q4_K_M` (derived from filename, without `.gguf`) |

Clients that hard-code the model ID (e.g., aider, opencode configs) must use the ID returned by this endpoint for the active backend. Example configurations in `examples/` document both values.

**During model loading** (llama.cpp only):
- Returns `503 Service Unavailable` until the model is fully loaded.
- `provision.sh` polls this endpoint during the startup wait loop.

### POST /v1/chat/completions

Standard OpenAI chat completions endpoint. Request and response schemas are identical between backends.

**Request**:

```json
{
  "model": "<model-id>",
  "messages": [
    {"role": "user", "content": "Hello"}
  ],
  "stream": false
}
```

**Response** (`200 OK`):

```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1704321600,
  "model": "<model-id>",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Hello! How can I help you?"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 20,
    "total_tokens": 30
  }
}
```

## Health / Readiness Probes

| Endpoint | llama.cpp behavior | Ollama behavior |
|----------|--------------------|-----------------|
| `GET /` | Not supported (404) | Returns `"Ollama is running"` (200 OK) |
| `GET /health` | Returns `{"status":"ok"}` immediately (liveness only) | Not supported |
| `GET /v1/models` | `200 OK` when model loaded; `503` during loading | `200 OK` once Ollama is up |

**Impact on `provision.sh`**: The startup wait loop must use `GET /v1/models` (returns `200`) when backend is `llama.cpp`, and `GET /` when backend is `ollama`.

## Model ID Mapping for Example Configs

The `examples/` directory configurations must be updated to document the llama.cpp model IDs:

| Model | Ollama ID | llama.cpp ID |
|-------|-----------|--------------|
| glm-4 | `glm4:latest` | `glm-4-9b-chat-Q4_K_M` |
| qwen3-coder | `qwen3-coder:latest` | `Qwen3-Coder-Next-Q4_K_M` |
| deepseek-v3 | `deepseek-v3:latest` | `DeepSeek-V3-Q4_K_M` |
| minimax-m1 | `minimax-m1:latest` | `minimax-m1` |
