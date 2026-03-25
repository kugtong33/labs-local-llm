# Feature Specification: Fix Model Cache Directory Permission Error

**Feature Branch**: `003-fix-cache-dir-permissions`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: provision script fails with "Permission denied" when trying to create `/opt/llm-models` because it requires root access, blocking first-time users who run without sudo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Works Out of the Box Without Sudo (Priority: P1)

As a developer running the setup for the first time on a fresh machine, I want `provision.sh` to succeed without requiring me to manually create a directory with sudo, so that the one-command promise of the setup holds true.

**Why this priority**: This is a blocking bug. The current default (`MODEL_CACHE_DIR=/opt/llm-models`) requires root to create, causing every first-time user without a pre-configured environment to hit an immediate failure. Nothing else matters until this is fixed.

**Independent Test**: On a machine where `/opt/llm-models` does not exist and the current user is not root, run `./scripts/provision.sh -m glm-4` — it must succeed without any sudo commands.

**Acceptance Scenarios**:

1. **Given** `/opt/llm-models` does not exist and the user has no root access, **When** the user runs `./scripts/provision.sh -m glm-4`, **Then** the script creates a model cache directory in a user-writable location and proceeds without error.
2. **Given** the user has not created a `.env` file, **When** the provision script runs, **Then** it uses a user-owned default cache directory, not a system directory.
3. **Given** the user has set `MODEL_CACHE_DIR` to a custom path in `.env`, **When** the provision script runs, **Then** it respects that value and attempts to create or use that path.
4. **Given** `MODEL_CACHE_DIR` is set to a system path that requires root (e.g., `/opt/llm-models`), **When** the directory cannot be created, **Then** the script shows a clear error explaining the problem and suggests either using sudo to create it or setting `MODEL_CACHE_DIR` to a writable path.

---

### User Story 2 - Default Cache Location Is Documented and Predictable (Priority: P2)

As a developer, I want to know where my model weights are stored by default, so that I can manage disk space and understand what will be deleted by `clean.sh --purge-models`.

**Why this priority**: Changing the default path is a user-visible behavioral change that must be clearly communicated. Without documentation, users won't know where their models are stored.

**Independent Test**: Read `.env.example` and `README.md` — both must clearly state the new default cache location and explain how to override it.

**Acceptance Scenarios**:

1. **Given** a user reads `.env.example`, **When** they look at the `MODEL_CACHE_DIR` entry, **Then** the default value is a user-writable path and the comment explains what it is and how to change it.
2. **Given** a user reads `README.md`, **When** they check the prerequisites or quick start section, **Then** the model storage location is mentioned and the expected disk space requirements are clear.

---

### Edge Cases

- What happens if the user-owned default directory exists but is not writable (e.g., wrong permissions set manually)?
- What if the user sets `MODEL_CACHE_DIR` to a path that already exists and is owned by root?
- What if `$HOME` is not set or resolves to an unexpected path?
- What if the available disk space at the default path is insufficient for the selected model?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The default value of `MODEL_CACHE_DIR` MUST be a path that a standard non-root user can create and write to without sudo (e.g., a directory under the user's home directory).
- **FR-002**: The provision script MUST attempt to create `MODEL_CACHE_DIR` if it does not exist, using only the current user's permissions.
- **FR-003**: If `MODEL_CACHE_DIR` cannot be created or written to, the script MUST display a clear error message that explains the cause and provides a concrete remediation step (e.g., change `MODEL_CACHE_DIR` in `.env` to a writable path, or use sudo to set up a system path).
- **FR-004**: The `.env.example` file MUST be updated to reflect the new user-writable default value for `MODEL_CACHE_DIR`.
- **FR-005**: The `README.md` MUST be updated to document the default model cache location and disk space expectations.
- **FR-006**: Users who have explicitly set `MODEL_CACHE_DIR` to a custom path MUST not be affected — their configured path continues to be used as-is.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer on a fresh machine can run `./scripts/provision.sh -m glm-4` successfully without any sudo commands or manual directory creation.
- **SC-002**: The permission error described in the bug report (`mkdir: cannot create directory '/opt/llm-models': Permission denied`) no longer occurs when using the default configuration.
- **SC-003**: The default model cache location is documented in both `.env.example` and `README.md`, so users can find it without reading the script source.

## Assumptions

- The fix changes the default `MODEL_CACHE_DIR` from `/opt/llm-models` to a user-owned path such as `$HOME/.local/share/llm-models` or `~/llm-models`.
- Users who previously set `MODEL_CACHE_DIR=/opt/llm-models` in their `.env` are not affected — the fix only changes the default, not existing overrides.
- The Docker named volume mount point must be updated to match the new default path in both `docker-compose.yml` and `.env.example`.
- Users who want to use a system path like `/opt/llm-models` can still do so by setting `MODEL_CACHE_DIR` manually and creating the directory with sudo — this use case remains supported.
