# Feature Specification: Add llama.cpp Backend Support

**Feature Branch**: `005-llama-cpp-backend`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: "- support llama.cpp setup
  - port all existing models to llama.cpp
  - add a flag to setup llama.cpp as the backend
  - generate the optimized configurations for llama.cpp for 8gb/16gb/24gb/32gb vram gpus
    - put it as a flag in the provisioning command
    - set 8gb optmized configuration as default
  - update documentation to include instructions for llama.cpp"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision a Model via llama.cpp Backend (Priority: P1)

A user with an 8 GB GPU wants to run local LLM inference using llama.cpp instead of Ollama. They add a single backend flag to the existing provision command and the system starts a llama.cpp inference server pre-configured for their GPU memory budget.

**Why this priority**: This is the core capability of the feature — without it, no other story can be exercised. It is the minimal viable slice that unlocks llama.cpp inference.

**Independent Test**: Can be fully tested by running `./scripts/provision.sh -m glm-4 -b llama.cpp` and verifying that an OpenAI-compatible API responds on the default port.

**Acceptance Scenarios**:

1. **Given** a clean environment with Docker available, **When** `./scripts/provision.sh -m glm-4 -b llama.cpp` is executed, **Then** a llama.cpp inference container named `llm-server` starts successfully and the API responds on port 11434.
2. **Given** a running llama.cpp server, **When** a chat-completions request is sent to `http://localhost:11434/v1/chat/completions`, **Then** the server returns a valid OpenAI-compatible response.
3. **Given** the backend flag is omitted, **When** `./scripts/provision.sh -m glm-4` is executed, **Then** the existing Ollama backend is used (backward compatibility preserved).
4. **Given** an invalid backend value, **When** `./scripts/provision.sh -m glm-4 -b unknown` is executed, **Then** the script exits with code 1 and prints a usage error to stderr.

---

### User Story 2 - Select VRAM-Optimized Configuration (Priority: P2)

A user with a 16 GB GPU wants to maximize performance by selecting the configuration tier that matches their hardware. They pass a VRAM tier flag to unlock a larger context window and higher GPU layer offloading.

**Why this priority**: The VRAM tier flag is the key differentiator that makes llama.cpp useful across diverse hardware. Without it, the feature delivers limited value beyond Ollama.

**Independent Test**: Can be tested by provisioning with `-b llama.cpp -V 16gb` and confirming that the server reports context size and GPU layer count consistent with the 16 GB profile.

**Acceptance Scenarios**:

1. **Given** a user with a 16 GB GPU, **When** `./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb` is executed, **Then** the server starts with parameters appropriate for 16 GB VRAM (larger context window and more GPU layers than the 8 GB default).
2. **Given** no VRAM tier flag is provided with `-b llama.cpp`, **When** the command runs, **Then** the 8 GB configuration is applied as the default.
3. **Given** a valid VRAM tier (8gb, 16gb, 24gb, 32gb), **When** the server starts, **Then** the applied configuration parameters reflect the selected tier.
4. **Given** an invalid VRAM tier value, **When** `./scripts/provision.sh -m glm-4 -b llama.cpp -V 48gb` is executed, **Then** the script exits with code 1 and lists valid tier options.

---

### User Story 3 - Use Any Supported Model with llama.cpp (Priority: P3)

A user wants to run any model listed in the model registry (glm-4, deepseek-v3, minimax-m1, qwen3-coder) using the llama.cpp backend, not just a subset.

**Why this priority**: Full model parity ensures that users who switch from Ollama to llama.cpp are not restricted in their model choices.

**Independent Test**: Can be tested by provisioning each model with `-b llama.cpp` and verifying the server starts and responds to API calls.

**Acceptance Scenarios**:

1. **Given** any model in the registry, **When** it is provisioned with `-b llama.cpp`, **Then** the server starts without errors.
2. **Given** a model not in the registry, **When** provisioned with any backend, **Then** the script exits with code 1 (existing validation unchanged).
3. **Given** the minimax-m1 model (which requires a user-provided GGUF), **When** the GGUF file is absent and `-b llama.cpp` is used, **Then** the script exits with a clear error message describing the required file path.

---

### User Story 4 - Consult llama.cpp Setup Documentation (Priority: P4)

A new user wants to understand how to set up and use the llama.cpp backend. They can follow the updated documentation to complete setup without needing external references.

**Why this priority**: Documentation is essential for adoption but does not block the core functionality. It is independently verifiable from the implementation.

**Independent Test**: Can be tested by a person unfamiliar with the project following only the documentation to successfully start a llama.cpp server.

**Acceptance Scenarios**:

1. **Given** the project documentation, **When** a user reads the llama.cpp section, **Then** they find step-by-step instructions covering prerequisites, provisioning with llama.cpp, VRAM tier selection, and model compatibility.
2. **Given** the documentation, **When** a user follows instructions for a specific VRAM tier, **Then** they can identify which tier matches their hardware and what trade-offs to expect (context size vs. memory usage).

---

### Edge Cases

- What happens when the user specifies `-b llama.cpp` on a machine with no GPU — does CPU fallback activate automatically?
- How does the system behave when the requested VRAM tier exceeds available GPU memory (e.g., `-V 32gb` on a 16 GB card)?
- What happens if a llama.cpp server is already running and `provision.sh` is called again with a different VRAM tier?
- How does `update.sh` behave when the running server uses the llama.cpp backend?
- What happens when `clean.sh --purge-models` is called — are llama.cpp GGUF files also removed from the volume?
- What if deepseek-v3 or another large model cannot fit within the 8 GB default tier — is provisioning blocked or does it warn and continue?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `provision.sh` MUST accept a `-b` flag (backend) with valid values `ollama` (default) and `llama.cpp`.
- **FR-002**: `provision.sh` MUST accept a `-V` flag (VRAM tier) with valid values `8gb` (default), `16gb`, `24gb`, and `32gb`; this flag applies only when `-b llama.cpp` is active.
- **FR-003**: System MUST start a llama.cpp inference server using the selected VRAM tier configuration when `-b llama.cpp` is specified.
- **FR-004**: The llama.cpp inference server MUST expose an OpenAI-compatible API on the same port as the Ollama backend (`http://localhost:${LLM_PORT:-11434}/v1`).
- **FR-005**: System MUST provide four named VRAM tier configurations (8gb, 16gb, 24gb, 32gb), each defining at minimum: context window size, number of GPU layers to offload, and batch size.
- **FR-006**: System MUST default to the 8 GB VRAM tier configuration when the `-V` flag is omitted alongside `-b llama.cpp`.
- **FR-007**: All models currently in `models/registry.conf` (glm-4, deepseek-v3, minimax-m1, qwen3-coder) MUST be supported with the llama.cpp backend.
- **FR-008**: Existing `provision.sh`, `clean.sh`, `update.sh`, and `status.sh` commands MUST continue to work without modification when `-b llama.cpp` is not specified (full backward compatibility).
- **FR-009**: `status.sh` MUST report the active backend (ollama or llama.cpp) and the active VRAM tier when displaying running server state.
- **FR-010**: `clean.sh` MUST stop the llama.cpp server container when it is running, respecting the same `--keep-models` and `--purge-models` semantics as for the Ollama backend.
- **FR-011**: Documentation MUST include a llama.cpp section covering prerequisites, provisioning commands, VRAM tier selection guidance, and per-model minimum tier requirements.
- **FR-012**: System MUST support CPU fallback for the llama.cpp backend when no GPU is detected, consistent with the existing Ollama CPU fallback behavior.
- **FR-013**: All new and modified scripts MUST pass `shellcheck` with no warnings.

### Key Entities

- **Backend**: The inference engine used to serve a model. Values: `ollama` (default, existing) or `llama.cpp` (new).
- **VRAM Tier Configuration**: A named set of llama.cpp server parameters (context window size, GPU layer count, batch size, and related knobs) optimized for a specific GPU memory budget — one configuration exists per tier: 8 GB, 16 GB, 24 GB, 32 GB.
- **Model Registry Entry**: A record in `models/registry.conf` extended to carry llama.cpp-specific metadata (GGUF variant identifier or source path) alongside existing Ollama fields.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can provision any supported model via llama.cpp by adding two or fewer flags to the existing provision command — no other workflow changes are required.
- **SC-002**: The default 8 GB VRAM configuration runs without out-of-memory errors on hardware with exactly 8 GB of GPU memory for all supported models that meet the 8 GB minimum requirement.
- **SC-003**: The OpenAI-compatible API endpoint returns structurally identical responses (same JSON schema) regardless of whether Ollama or llama.cpp is used as the backend.
- **SC-004**: Each VRAM tier (8 GB → 16 GB → 24 GB → 32 GB) provides a measurably larger context window or higher GPU layer offload count than the tier below it.
- **SC-005**: A user unfamiliar with llama.cpp can complete a successful first provisioning by following only the updated project documentation, without consulting external resources.
- **SC-006**: All existing Ollama-based commands execute without error after the llama.cpp changes are merged (zero regression in existing behavior).

## Assumptions

- llama.cpp will be deployed via the official Docker image (`ghcr.io/ggml-org/llama.cpp:server` or equivalent), consistent with the project's existing Docker-first approach.
- Models will be served as GGUF-quantized files; the registry will map each model to its recommended GGUF variant.
- The existing Docker named volume (`llm-model-cache`) will be reused to store GGUF files for the llama.cpp backend.
- VRAM tier configurations are static, pre-defined parameter sets embedded in the provisioning scripts — no runtime auto-tuning is required for v1.
- The 8 GB default tier is intentionally conservative: it prioritizes stability and broad hardware compatibility over maximum context length or throughput.
- minimax-m1's existing requirement for a user-provided GGUF file at `$MODEL_CACHE_DIR/minimax-m1.gguf` is preserved and applies to the llama.cpp backend.
- deepseek-v3 may not fit within the 8 GB VRAM tier; documentation and validation will note per-model minimum tier requirements and warn accordingly.
- `shellcheck` compliance is required for all new or modified scripts, consistent with existing code style conventions.
