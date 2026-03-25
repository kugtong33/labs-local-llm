# Contract: Inference Server API

**Feature**: `001-local-llm-coding-setup`
**Date**: 2026-03-25
**Type**: HTTP API (OpenAI-compatible)

The local inference server (Ollama) exposes an OpenAI-compatible HTTP API. This contract defines the minimum endpoints required for AI coding agent integration.

**Base URL**: `http://localhost:11434/v1`
**Authentication**: Any non-empty string accepted as API key (`Authorization: Bearer local`)

---

## Required Endpoints

### `GET /v1/models`

List available models on the server.

**Request**: No body.

**Response** (200 OK):
```json
{
  "object": "list",
  "data": [
    {
      "id": "glm4:latest",
      "object": "model",
      "created": 1711000000,
      "owned_by": "local"
    }
  ]
}
```

**Contract requirements**:
- `data[].id` must exactly match the model name used in agent configuration
- At least one model must appear when the server is in `ready` state

---

### `POST /v1/chat/completions`

Submit a chat prompt and receive a completion.

**Request body**:
```json
{
  "model": "glm4:latest",
  "messages": [
    {"role": "system", "content": "You are a coding assistant."},
    {"role": "user", "content": "Write a Python hello world function."}
  ],
  "temperature": 0.2,
  "max_tokens": 4096,
  "stream": true
}
```

**Required request fields**:
- `model` (string) — must match a model ID from `/v1/models`
- `messages` (array) — at least one message with `role` and `content`

**Optional request fields**:
- `temperature` (float, 0–2) — default 1.0
- `max_tokens` (integer) — default model-specific
- `stream` (boolean) — default false; all coding agents default to `true`

---

#### Non-streaming response (200 OK, `stream: false`):

```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1711000000,
  "model": "glm4:latest",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Here is a Python hello world function:\n\n```python\ndef hello():\n    print('Hello, world!')\n```"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 32,
    "completion_tokens": 28,
    "total_tokens": 60
  }
}
```

---

#### Streaming response (200 OK, `stream: true`):

Content-Type: `text/event-stream`

Each chunk:
```
data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1711000000,"model":"glm4:latest","choices":[{"index":0,"delta":{"role":"assistant","content":"Here"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1711000000,"model":"glm4:latest","choices":[{"index":0,"delta":{"content":" is"},"finish_reason":null}]}

data: {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1711000000,"model":"glm4:latest","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
```

**Critical**: The stream MUST terminate with `data: [DONE]`. Missing this causes all coding agents (OpenCode, Continue, Aider) to hang indefinitely.

---

## Error Responses

| HTTP Status | When | Example |
|---|---|---|
| 400 | Malformed request body | `{"error": {"message": "invalid request", "type": "invalid_request_error"}}` |
| 401 | Missing or empty Authorization header | `{"error": {"message": "unauthorized"}}` |
| 404 | Model not found | `{"error": {"message": "model 'foo' not found"}}` |
| 500 | Inference error | `{"error": {"message": "internal server error"}}` |

---

## Agent Configuration Reference

### OpenCode (`~/.config/opencode/config.toml`)

```toml
[model]
provider = "openai"
model = "glm4:latest"
base_url = "http://localhost:11434/v1"
api_key = "local"
```

### Continue (`~/.continue/config.json`)

```json
{
  "models": [
    {
      "title": "Local GLM-4",
      "provider": "openai",
      "model": "glm4:latest",
      "apiBase": "http://localhost:11434/v1",
      "apiKey": "local"
    }
  ]
}
```

### Aider (`.aider.conf.yml` in project root)

```yaml
model: openai/glm4:latest
openai-api-base: http://localhost:11434/v1
openai-api-key: local
```

**Note**: The `model` field value must exactly match the `id` returned by `GET /v1/models`.

---

## Health Check

Ollama exposes `GET /` (root) returning `"Ollama is running"` and a health endpoint:

```
GET http://localhost:11434/
→ 200 OK  "Ollama is running"
```

The Docker Compose healthcheck uses this endpoint to gate container readiness.
