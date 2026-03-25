# Feature Specification: Curate Model Registry for Local Hardware

**Feature Branch**: `006-curate-model-registry`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: "- remove very large llms that will not be feasible to run on local
  - deepseek-v3
  - minimax-m1

- add more quantized models that can run on an old gpu hardware
  - deepseek-coder-lite
  - codellama-7b
  - codestral-7b
  - starcoder2-7b
  - starcoder2-3b
  - starcoder2-15b"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remove Infeasible Large Models (Priority: P1)

A developer wants to run a local LLM on their workstation. When they list supported models, they no longer see deepseek-v3 or minimax-m1 — models that require 80–200 GB of VRAM or RAM and are impractical on consumer hardware. The supported model list contains only models that can realistically be provisioned on local machines.

**Why this priority**: Removing confusing, impractical options is the most urgent change. A user attempting to provision deepseek-v3 would trigger a massive (hundreds of GB) download and likely fail with out-of-memory errors. minimax-m1 required a manual GGUF download and 40 GB VRAM. Removing both reduces user frustration immediately.

**Independent Test**: Can be fully tested by running `./scripts/provision.sh -m deepseek-v3` and `./scripts/provision.sh -m minimax-m1` — both must exit with an "unsupported model" error. Neither model appears in the supported models list printed in any error message.

**Acceptance Scenarios**:

1. **Given** the updated registry, **When** a user runs `./scripts/provision.sh -m deepseek-v3`, **Then** the script exits with code 1 and prints "Unsupported model" along with the current supported model list (which does not include deepseek-v3).
2. **Given** the updated registry, **When** a user runs `./scripts/provision.sh -m minimax-m1`, **Then** the script exits with code 1 and prints "Unsupported model" (minimax-m1 is not in the supported list).
3. **Given** a user who had deepseek-v3 or minimax-m1 in a previous agent config, **When** they attempt to provision either model, **Then** they receive a clear error pointing them to the available model list.
4. **Given** existing users of glm-4 and qwen3-coder, **When** they provision those models after this change, **Then** provisioning works identically to before (no regression).

---

### User Story 2 - Provision New Code-Focused Models on Consumer Hardware (Priority: P2)

A developer with an older GPU (4–8 GB VRAM) wants to run a coding-focused LLM locally. They can now choose from six new models — deepseek-coder-lite, codellama-7b, codestral-7b, starcoder2-3b, starcoder2-7b, and starcoder2-15b — and provision any of them using the same single command they already know.

**Why this priority**: Adding practical, runnable alternatives is the core value of this feature. Users who lost deepseek-v3/minimax-m1 need better options, and developers with older hardware gain access to capable coding models that previously weren't listed.

**Independent Test**: Can be fully tested by running `./scripts/provision.sh -m codellama-7b` on hardware with 6 GB VRAM and verifying the model serves code completion requests via the API. Each of the six new models can be tested independently in the same way.

**Acceptance Scenarios**:

1. **Given** a machine with 4 GB VRAM, **When** `./scripts/provision.sh -m starcoder2-3b` is run, **Then** the server starts and responds to code completion requests.
2. **Given** a machine with 6 GB VRAM, **When** any of codellama-7b, codestral-7b, or starcoder2-7b is provisioned, **Then** the server starts and responds to requests.
3. **Given** a machine with 8 GB VRAM, **When** `./scripts/provision.sh -m deepseek-coder-lite` is run, **Then** the server starts successfully.
4. **Given** a machine with 12 GB VRAM, **When** `./scripts/provision.sh -m starcoder2-15b` is run, **Then** the server starts successfully.
5. **Given** any of the six new models, **When** provisioned with `-b llama.cpp`, **Then** the llama.cpp backend auto-downloads the GGUF and starts the server.
6. **Given** an invalid VRAM tier for a model (e.g., starcoder2-15b on 8gb tier), **When** provisioned with `-b llama.cpp -V 8gb`, **Then** the system emits a warning about the minimum recommended tier.

---

### User Story 3 - Consult Updated Documentation (Priority: P3)

A new user reads the README to choose a model. The documentation accurately reflects the current supported model list — showing only the eight practical models with their hardware requirements — and does not mention the removed models.

**Why this priority**: Documentation is essential for adoption but is independently verifiable from the registry changes. It can be completed in parallel with or after the registry updates.

**Independent Test**: Can be tested by reading the README models table and confirming it lists exactly the eight supported models with accurate VRAM/RAM requirements. No reference to deepseek-v3 or minimax-m1 remains.

**Acceptance Scenarios**:

1. **Given** the updated README, **When** a user reads the models table, **Then** they see exactly 8 models: glm-4, qwen3-coder, deepseek-coder-lite, codellama-7b, codestral-7b, starcoder2-3b, starcoder2-7b, starcoder2-15b — with accurate VRAM/RAM figures.
2. **Given** the updated README, **When** searched for "deepseek-v3" or "minimax-m1", **Then** neither name appears in the user-facing documentation.
3. **Given** the updated documentation, **When** a user with a 6 GB GPU reads it, **Then** they can immediately identify which models are suitable for their hardware without additional research.

---

### Edge Cases

- What happens if a user has a locally downloaded deepseek-v3 or minimax-m1 GGUF in their model cache after removal — will `clean.sh --purge-models` still delete it?
- What if a user's agent config (opencode, continue, aider) still references a removed model's ID — will the provisioning error message guide them to alternatives?
- What is the behaviour when starcoder2-15b (12 GB minimum) is attempted on a machine with only 8 GB VRAM?
- Do the new models require any special setup steps (e.g., accepting a license) before they can be pulled?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: deepseek-v3 and minimax-m1 MUST be removed from the supported model registry so that `-m deepseek-v3` and `-m minimax-m1` produce an "unsupported model" error.
- **FR-002**: The following six models MUST be added to the supported model registry: `deepseek-coder-lite`, `codellama-7b`, `codestral-7b`, `starcoder2-3b`, `starcoder2-7b`, `starcoder2-15b`.
- **FR-003**: Each new model registry entry MUST specify: minimum VRAM (GB), minimum RAM (GB), status (`stable`), Ollama pull identifier, GGUF HuggingFace repository, GGUF filename, and minimum llama.cpp VRAM tier.
- **FR-004**: All six new models MUST be provisionable via the Ollama backend using `./scripts/provision.sh -m <model>` without any manual setup steps.
- **FR-005**: All six new models MUST be provisionable via the llama.cpp backend using `./scripts/provision.sh -m <model> -b llama.cpp`, with GGUF files auto-downloaded on first run.
- **FR-006**: The minimax-m1 Modelfile (`models/minimax-m1.Modelfile`) MUST be removed as it is no longer needed.
- **FR-007**: The README models table MUST be updated to show exactly the eight current models (glm-4, qwen3-coder, and the six new models) with accurate hardware requirements.
- **FR-008**: All references to deepseek-v3 and minimax-m1 MUST be removed from user-facing documentation (README, example configs, CLAUDE.md).
- **FR-009**: glm-4 and qwen3-coder MUST remain in the registry unchanged and continue to work exactly as before.
- **FR-010**: The example agent configurations (`examples/`) MUST be updated to remove references to removed models and add entries for the new models where applicable.

### Key Entities

- **Model Registry Entry**: A record in `models/registry.conf` describing a supported model. Two entries are removed; six new entries are added. The eight-column format introduced in feature 005 (`id|ollama_id|min_vram_gb|min_ram_gb|status|gguf_hf_repo|gguf_filename|min_vram_tier`) is preserved.
- **Supported Model Set**: The complete list of models a user can provision. Changes from {deepseek-v3, glm-4, minimax-m1, qwen3-coder} to {codellama-7b, codestral-7b, deepseek-coder-lite, glm-4, qwen3-coder, starcoder2-3b, starcoder2-7b, starcoder2-15b}.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: deepseek-v3 and minimax-m1 produce "unsupported model" errors in 100% of provisioning attempts after this change is applied.
- **SC-002**: All six new models can be successfully provisioned and serve API responses on hardware meeting their minimum VRAM requirements.
- **SC-003**: The five models with 6 GB or less VRAM requirement (starcoder2-3b at 4 GB, codellama-7b / codestral-7b / starcoder2-7b at 6 GB, deepseek-coder-lite at 8 GB) start and respond within the existing 3-minute server-ready timeout.
- **SC-004**: The supported model list visible in provisioning error messages and documentation contains exactly 8 models — no more, no less.
- **SC-005**: A user with a 6 GB GPU can identify at least three suitable models and successfully provision one by following the README alone.

## Assumptions

- "Old GPU hardware" means consumer GPUs with approximately 4–12 GB VRAM (e.g., GTX 1060 6 GB, RTX 2060 8 GB, RTX 3060 12 GB).
- deepseek-coder-lite refers to DeepSeek-Coder-V2-Lite, a mixture-of-experts model with 2.4B active parameters; it requires approximately 8 GB VRAM at Q4_K_M quantization.
- starcoder2-15b requires approximately 10–12 GB VRAM at Q4_K_M quantization and is therefore the only new model that does not run on a 6–8 GB GPU; it targets 12 GB+ GPUs.
- All six new models are available in the Ollama model library and can be pulled without requiring a license agreement or account.
- All six new models have Q4_K_M GGUF quantizations published on HuggingFace suitable for llama.cpp inference.
- The minimax-m1.Modelfile is no longer needed once minimax-m1 is removed from the registry; it will be deleted.
- Existing user agent configurations that reference deepseek-v3 or minimax-m1 will break after removal; the README and provisioning error messages will guide users to alternatives.
- The eight-column registry format introduced in feature 005 is stable and does not need to change.
