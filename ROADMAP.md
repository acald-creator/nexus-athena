# Nexus Athena Roadmap

Aligned with the [100 Days of Underground Nexus](../core-nexus/docs/100-days-challenge.md) challenge.

## Completed

- [x] Multi-stage Docker build (athena-core + athena-full, multi-platform via buildx)
- [x] Runtime profiles: standard, packet-lab, exploit-lab, agent, agent-ics
- [x] Compose profiles for all 5 modes with proper capability declarations
- [x] Profile launcher script (`scripts/run-athena-profile.sh`) with target argument
- [x] Profile validation script (`scripts/validate-athena-profiles.sh`)
- [x] Kubernetes base manifests + local/prod/agent overlays
- [x] Architecture doc rewritten as implemented (not proposed)
- [x] LLM agent mode: OPAR loop wired via entrypoint + `__main__.py`
- [x] Agent config directory (tool-registry, allowlist, targets, LLM config)
- [x] Build script (`scripts/build-athena-image.sh`) for cross-repo image builds
- [x] Entrypoint validation with structured errors and `--dry-run`
- [x] Traffic labeling (env vars + HTTP headers for SOC dashboard filtering)
- [x] Removed legacy files (Dockerfile.arm64, .gitlab-ci.yml, stale SPDX)

## Phase 1: Foundation (Days 1-20)

- [ ] First live OPAR run against Juice Shop target
- [ ] Add Juice Shop container to compose as a reachable target on athena_lab network
- [ ] Fix Rust crate compilation (commit `Cargo.lock` in athena-agents)
- [ ] Verify ground-truth JSONL output populates in athena_output volume
- [ ] Test `run-athena-profile.sh agent juice-shop` end-to-end with Ollama

## Phase 2: Detection Engineering (Days 21-40)

- [ ] Add new tools to tool-registry (directory brute-force, subdomain enum)
- [ ] Add OpenPLC container to compose as a Modbus target
- [ ] Run Modbus agent against OpenPLC, verify safe-range enforcement
- [ ] Verify boundary violation halts with `needs_review` ground-truth record
- [ ] Verify all agent traffic carries `X-Athena-Scenario` headers (testable in Suricata)

## Phase 3: Agent Intelligence (Days 41-60)

- [ ] Support multi-step attack chains (sequence objectives in target TOML)
- [ ] Load skills from MinIO at OPAR Plan phase startup
- [ ] Measure token savings: same scenario with vs without loaded skill
- [ ] Add second LLM backend option (vLLM or llama.cpp) for comparison
- [ ] Add planning quality metrics (actions to objective, dead ends)

## Phase 4: Hardening (Days 61-80)

- [ ] Deploy agent in real k3d cluster with agent overlay
- [ ] Verify NetworkPolicy blocks unauthorized egress (test escape attempts)
- [ ] Add SBOM generation to `build-athena-image.sh` (syft integration)
- [ ] Add cosign signing to local build workflow
- [ ] Add image verification step to `run-athena-profile.sh`
- [ ] Add resource limits and OOM handling for long-running scenarios

## Phase 5: Advanced (Days 81-100)

- [ ] Add vcan interface setup to compose (virtual CAN Bus lab)
- [ ] Create CAN Bus target config with ID ranges and fuzz params
- [ ] Run CAN fuzzer agent, analyze ID space coverage
- [ ] Multi-agent: two OPAR loops against different targets simultaneously
- [ ] Coordination protocol (agent A informs agent B of findings)
- [ ] Scoring engine: automated effectiveness measurement per scenario

## Deferred (Post-Challenge)

- Fix GitHub Actions CI (fork constraint — address when repo ownership is resolved)
- Publish images to multiple registries (GHCR, GitLab, Docker Hub)
- Internal container registry on Kubernetes for trusted distribution
- Align release lifecycle with Underground Nexus component maturity gates
