---
inclusion: auto
---

# Nexus Athena Offensive Security Context

This workspace contains the Athena red-team and adversary emulation platform. When working here:

## Key Files
- `architecture.md` — Athena architecture guide
- `crates/` — Rust tooling (athena-modbus, athena-canbus, athena-common)
- `orchestrator/` — Python OPAR loop and safety controls
- `config/tool-registry.toml` — tool definitions with capability gates
- `config/targets/` — TOML target configurations with safe ranges
- `eval/` — evaluation metrics

## Applicable Skills
When working in this repo, the following skills from `~/.kiro/skills/` are most relevant:
- `red-team-athena-workflow.md` — primary workflow for all offensive work
- `ics-ot-protocol-analysis.md` — for Modbus/CAN protocol tasks
- `log-code-bug-analysis.md` — for debugging Rust crates or Python orchestrator

## Guardrails
- Keep offensive tooling isolated from SOC and analyst desktop
- Never bypass safe-range validation
- Document runtime privileges as explicit profiles
- No broad host Docker access in default examples
- All tool output as structured JSON (stdout=data, stderr=errors)
- Deterministic PRNG for reproducible fuzzing
