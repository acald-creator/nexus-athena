# Implementation Plan: Athena Agent Runtime Wiring

## Overview

Wire the `athena-agents` OPAR orchestrator into the `nexus-athena` Docker image so that `./scripts/run-athena-profile.sh agent <target>` launches the autonomous observe/plan/act/reflect loop. Implementation spans: Dockerfile build stages (Rust + Python), entrypoint script, `__main__.py` module, compose profile updates, and run script enhancements. Work touches both `nexus-athena` and `athena-agents` repositories.

## Tasks

- [ ] 1. Dockerfile: Add rust-builder and python-builder stages
  - [ ] 1.1 Add `rust-builder` stage to compile Rust crates from `athena-agents/crates/`
    - Use `rust:1.77-slim-bookworm` base image
    - Add `ATHENA_AGENTS_PATH` build arg (default: `./athena-agents`)
    - Copy `Cargo.toml`, `Cargo.lock`, and `crates/` from build context
    - Run `cargo build --release` for all workspace members
    - Handle `TARGETPLATFORM` for multi-arch cross-compilation (amd64/arm64)
    - Output binaries: `athena-scanner`, `athena-fuzzer`, `athena-crafter`, `athena-modbus`, `athena-canbus`
    - _Requirements: 11.1, 11.3_

  - [ ] 1.2 Add `python-builder` stage to install Python orchestrator with pinned deps
    - Use `python:3.11-slim-bookworm` base image
    - Copy `athena-agents/pyproject.toml` and source into the stage
    - Generate or use `requirements.lock` with hash-verified installs (`--require-hashes`)
    - Install only main dependencies (exclude `dev` optional-dependencies)
    - Install to a prefix path (`/install`) for clean COPY into final stage
    - _Requirements: 2.1, 2.2, 2.4, 2.5_

  - [ ] 1.3 Integrate builder outputs into `athena-core` stage
    - COPY Rust binaries from `rust-builder` to `/usr/local/bin/`
    - COPY Python site-packages from `python-builder` to `/usr/local/lib/python3/dist-packages/` (or equivalent)
    - COPY entrypoint script to `/usr/local/bin/athena-agent-entrypoint.sh` and `chmod +x`
    - Set `ENV ATHENA_BIN_DIR=/usr/local/bin`
    - Ensure `python3 -m orchestrator` works without `PYTHONPATH` manipulation
    - Do NOT include `config/` directory in the image
    - _Requirements: 2.3, 11.2, 11.3, 11.4, 11.5, 11.6_

- [ ] 2. Create entrypoint script (`scripts/athena-agent-entrypoint.sh`)
  - [ ] 2.1 Write the validation and bootstrap entrypoint script
    - Create `scripts/athena-agent-entrypoint.sh` in `nexus-athena` repo
    - Implement sequential validation: check `ATHENA_TARGET` non-empty, check `ATHENA_TOOL_REGISTRY` non-empty and file exists, check `ATHENA_ALLOWLIST` non-empty and file exists, check `allowlist.sha256` exists, check target config file exists at `${ATHENA_CONFIG_DIR}/targets/${ATHENA_TARGET}.toml`
    - Set `PYTHONUNBUFFERED=1` before exec
    - On validation success: `exec python3 -m orchestrator --target "${ATHENA_TARGET}" --config-dir "${ATHENA_CONFIG_DIR:-/opt/athena/config}"`
    - On any validation failure: print structured error to stderr (format: `ERROR: [athena-agent-entrypoint] <desc>`) and exit 1
    - Support `--dry-run` flag: perform all validation, print config summary, exit 0 without launching orchestrator
    - Default `ATHENA_CONFIG_DIR` to `/opt/athena/config` if unset
    - Default `OLLAMA_HOST` to `http://host.docker.internal:11434` if unset
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 1.3, 1.4, 1.5, 3.2, 3.4_

- [ ] 3. Create `orchestrator/__main__.py` module (in `athena-agents` repo)
  - [ ] 3.1 Implement CLI argument parsing and configuration loading
    - Create `athena-agents/orchestrator/__main__.py`
    - Parse `--target` and `--config-dir` CLI arguments using `argparse`
    - Load `llm.toml` from config dir and construct appropriate `LLMBackend` instance
    - Load `tool-registry.toml` via `ToolRegistry.load()`
    - Read `allowlist.sha256` for expected hash value
    - Read `ATHENA_CAPABILITIES` env var, split on comma
    - Read `ATHENA_SCENARIO_LABEL` env var
    - Construct `GroundTruthEmitter` respecting `ATHENA_GT_OUTPUT` env var (default: `/opt/athena/output/ground-truth.jsonl`; if unset write to stdout)
    - _Requirements: 1.1, 3.3, 4.2, 6.2, 6.3_

  - [ ] 3.2 Implement LLM health check, safety controls, and scenario execution
    - Perform LLM health check with retry: 3 attempts, exponential backoff (1s, 2s, 4s), exit non-zero if unreachable
    - Override `llm.toml` URL with `OLLAMA_HOST` env var when `type = "ollama"`
    - Invoke allowlist SHA-256 verification before executing actions
    - Halt and exit non-zero if allowlist verification fails (missing file, hash mismatch, malformed JSON)
    - Construct `RateLimiter` with parameters from `llm.toml` or defaults
    - Construct `AgentOrchestrator` with all dependencies, pass `scenario_label` from env
    - Load `ScenarioConfig` from `targets/${ATHENA_TARGET}.toml`
    - Call `orchestrator.run_scenario()` with capability gates enforced
    - Write final `ScenarioResult` summary record to ground-truth on completion
    - Exit 0 on success, non-zero on failure (boundary violation emits `needs_review` record)
    - _Requirements: 4.3, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.4, 6.5_

  - [ ] 3.3 Implement traffic labeling in orchestrator startup
    - Inject `X-Athena-Scenario` and `X-Athena-Run-ID` HTTP headers into all outbound HTTP requests
    - Set `ATHENA_SCENARIO_ID` and `ATHENA_SCENARIO_LABEL` env vars for subprocess tool invocations
    - Include `User-Agent: Athena-Agent/<version>` header in all HTTP-based tool traffic
    - Pass `ATHENA_SCENARIO_LABEL` from compose environment through to orchestrator's `scenario_label` parameter
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [ ] 4. Checkpoint - Validate entrypoint and orchestrator module
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Update compose profiles (`deploy/compose/athena-profiles.yml`)
  - [ ] 5.1 Update `athena.agent` service with entrypoint, volumes, and environment
    - Replace `command: ["sleep", "infinity"]` with `command: ["/usr/local/bin/athena-agent-entrypoint.sh"]`
    - Add volume mount: `${ATHENA_CONFIG_PATH:-./config}:/opt/athena/config:ro`
    - Add named volume mount: `athena_output:/opt/athena/output`
    - Add environment variables: `ATHENA_CONFIG_DIR=/opt/athena/config`, `ATHENA_TARGET=${ATHENA_TARGET:-}`, `ATHENA_GT_OUTPUT=/opt/athena/output/ground-truth.jsonl`
    - Ensure `extra_hosts: ["host.docker.internal:host-gateway"]` is present
    - _Requirements: 8.1, 8.2, 8.3, 8.5, 3.1, 3.3_

  - [ ] 5.2 Update `athena.agent-ics` service with matching config plus ICS capabilities
    - Apply same changes as `athena.agent` (entrypoint, volumes, environment)
    - Ensure `ATHENA_CAPABILITIES=ICS_WRITE,CAN_INJECT` env var is present
    - Ensure `cap_add: [NET_RAW]` remains
    - _Requirements: 8.4, 1.2_

  - [ ] 5.3 Add top-level `volumes` section declaring `athena_output`
    - Add `volumes:` block with `athena_output: { driver: local }`
    - _Requirements: 8.6, 6.1_

- [ ] 6. Update run script (`scripts/run-athena-profile.sh`)
  - [ ] 6.1 Add target argument passthrough for agent profiles
    - For `agent` case: capture `$2` as target, export `ATHENA_TARGET="${2:-${ATHENA_TARGET:-}}"`
    - Print configured target and LLM endpoint to stdout before starting compose
    - For `agent-ics` case: same target passthrough with `ATHENA_TARGET` export
    - Ensure existing behavior is preserved when no target argument is provided (pass-through existing env var)
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 7. Checkpoint - Validate compose and run script changes
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Integration tests and smoke tests
  - [ ]* 8.1 Write shell-based integration tests for entrypoint validation
    - Create `tests/integration/test-entrypoint.sh` in `nexus-athena`
    - Test: `--dry-run` with valid env and files exits 0
    - Test: missing `ATHENA_TARGET` exits 1 with structured error
    - Test: missing tool-registry file exits 1 with structured error
    - Test: missing allowlist file exits 1 with structured error
    - Test: missing target config file exits 1 with structured error
    - Test: missing `allowlist.sha256` exits 1 with structured error
    - _Requirements: 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ]* 8.2 Write pytest unit tests for `orchestrator/__main__.py`
    - Create `tests/python/test_main.py` in `athena-agents`
    - Test CLI argument parsing (--target, --config-dir)
    - Test LLM health-check retry logic with mocked httpx client
    - Test configuration loading integration (tool-registry, allowlist, llm.toml)
    - Test ground-truth emitter respects `ATHENA_GT_OUTPUT` env var
    - _Requirements: 4.3, 3.3, 6.2, 6.3_

  - [ ]* 8.3 Write Dockerfile smoke test script
    - Create `tests/smoke/test-agent-image.sh` in `nexus-athena`
    - Verify Rust binaries exist and are executable: `docker run --rm <image> ls /usr/local/bin/athena-*`
    - Verify Python module is importable: `docker run --rm <image> python3 -c "import orchestrator"`
    - Verify entrypoint is executable: `docker run --rm <image> test -x /usr/local/bin/athena-agent-entrypoint.sh`
    - Run `docker compose config` on updated compose file to validate YAML syntax
    - _Requirements: 2.3, 11.3, 11.4_

- [ ] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Work spans two repos: Dockerfile/compose/entrypoint/run-script in `nexus-athena`, `__main__.py` in `athena-agents`
- The orchestrator logic (OPAR loop, safety controls, tool registry, ground-truth emitter) already exists in `athena-agents` — this feature packages and wires it
- No property-based tests for this feature (infrastructure wiring, not algorithmic logic)
- Config directory is NOT baked into the image — runtime volume mounts only
- `requirements.lock` (or equivalent hash-verified lockfile) should be generated from `pyproject.toml` before the Dockerfile build

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "2.1"] },
    { "id": 1, "tasks": ["1.3", "3.1"] },
    { "id": 2, "tasks": ["3.2", "3.3"] },
    { "id": 3, "tasks": ["5.1", "5.2", "5.3", "6.1"] },
    { "id": 4, "tasks": ["8.1", "8.2", "8.3"] }
  ]
}
```
