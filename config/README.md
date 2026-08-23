# Athena Agent Configuration

This directory provides runtime configuration for the OPAR agent loop.
It is mounted read-only into agent containers at `/opt/athena/config`.

## Files

| File | Purpose |
|------|---------|
| `tool-registry.toml` | Available tools with argument schemas and capability requirements |
| `allowlist.json` | Approved targets (SHA-256 verified at startup) |
| `allowlist.sha256` | SHA-256 hash of allowlist.json for integrity verification |
| `llm.toml` | LLM backend configuration (model, URL, planning parameters) |
| `targets/` | Per-target scenario configs with objectives and safe ranges |

## Adding a Target

1. Create `targets/<name>.toml` with host, port, protocol, scenario details
2. Add the host to `allowlist.json` with allowed ports
3. Regenerate hash: `shasum -a 256 allowlist.json | cut -d' ' -f1 > allowlist.sha256`

## Grimoire (grimoire-workbench)

Two identities — pick one and keep it everywhere (target TOML, allowlist, planner URL):

| Target | Host:port | When |
|--------|-----------|------|
| `grimoire` | `127.0.0.1:3010` | Host orchestrator + `cargo run -p grimoire-web` |
| `grimoire-lab` | `grimoire.lab:3000` | `athena.agent` + workbench `docker-compose.athena.yml` |

Do not add a `localhost` row for Grimoire. `localhost` is already novel-directory `:8090`; first-match wins.

## Security

- `allowlist.json` is SHA-256 verified before every execution cycle
- Tools requiring elevated capabilities (ICS_WRITE, CAN_INJECT) only run in matching profiles
- Safe ranges in target configs are non-negotiable — the agent cannot write outside them
