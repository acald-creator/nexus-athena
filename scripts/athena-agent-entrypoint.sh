#!/usr/bin/env bash
# athena-agent-entrypoint.sh — Validate environment and launch OPAR orchestrator.
#
# Usage:
#   athena-agent-entrypoint.sh           # Run the OPAR loop
#   athena-agent-entrypoint.sh --dry-run # Validate only, don't launch
#
# Required environment:
#   ATHENA_TARGET          — Target identifier (matches targets/<name>.toml)
#   ATHENA_TOOL_REGISTRY   — Path to tool-registry.toml
#   ATHENA_ALLOWLIST       — Path to allowlist.json
#
# Optional environment:
#   ATHENA_CONFIG_DIR      — Config root (default: /opt/athena/config)
#   ATHENA_GT_OUTPUT       — Ground-truth output path (default: /opt/athena/output/ground-truth.jsonl)
#   ATHENA_CAPABILITIES    — Comma-separated capabilities (e.g., ICS_WRITE,CAN_INJECT)
#   ATHENA_SCENARIO_LABEL  — Scenario label for traffic tagging
#   OLLAMA_HOST            — LLM backend URL (default: http://host.docker.internal:11434)

set -euo pipefail

# Defaults
ATHENA_CONFIG_DIR="${ATHENA_CONFIG_DIR:-/opt/athena/config}"
OLLAMA_HOST="${OLLAMA_HOST:-http://host.docker.internal:11434}"
ATHENA_GT_OUTPUT="${ATHENA_GT_OUTPUT:-/opt/athena/output/ground-truth.jsonl}"
DRY_RUN=false

# Parse flags
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

# Error helper
error() {
  echo "ERROR: [athena-agent-entrypoint] $1" >&2
  if [[ -n "${2:-}" ]]; then
    echo "  Expected: $2" >&2
  fi
  if [[ -n "${3:-}" ]]; then
    echo "  Got: $3" >&2
  fi
  exit 1
}

# --- Validation ---

# 1. Check ATHENA_TARGET
if [[ -z "${ATHENA_TARGET:-}" ]]; then
  error "ATHENA_TARGET not set" \
    "A target identifier matching a file in ${ATHENA_CONFIG_DIR}/targets/" \
    "(empty)"
fi

# 2. Check ATHENA_TOOL_REGISTRY
if [[ -z "${ATHENA_TOOL_REGISTRY:-}" ]]; then
  error "ATHENA_TOOL_REGISTRY not set" \
    "Path to tool-registry.toml" \
    "(empty)"
fi
if [[ ! -f "${ATHENA_TOOL_REGISTRY}" ]]; then
  error "Tool registry file not found" \
    "File at ${ATHENA_TOOL_REGISTRY}" \
    "(file does not exist)"
fi

# 3. Check ATHENA_ALLOWLIST
if [[ -z "${ATHENA_ALLOWLIST:-}" ]]; then
  error "ATHENA_ALLOWLIST not set" \
    "Path to allowlist.json" \
    "(empty)"
fi
if [[ ! -f "${ATHENA_ALLOWLIST}" ]]; then
  error "Allowlist file not found" \
    "File at ${ATHENA_ALLOWLIST}" \
    "(file does not exist)"
fi

# 4. Check allowlist SHA-256 hash file
ALLOWLIST_HASH="${ATHENA_CONFIG_DIR}/allowlist.sha256"
if [[ ! -f "${ALLOWLIST_HASH}" ]]; then
  error "Allowlist hash file not found" \
    "File at ${ALLOWLIST_HASH}" \
    "(file does not exist — generate with: shasum -a 256 allowlist.json | cut -d' ' -f1 > allowlist.sha256)"
fi

# 5. Check target config file
TARGET_CONFIG="${ATHENA_CONFIG_DIR}/targets/${ATHENA_TARGET}.toml"
if [[ ! -f "${TARGET_CONFIG}" ]]; then
  error "Target config not found" \
    "File at ${TARGET_CONFIG}" \
    "(file does not exist — create a target TOML in config/targets/)"
fi

# --- Validation passed ---

export PYTHONUNBUFFERED=1
export OLLAMA_HOST
export ATHENA_GT_OUTPUT

if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== athena-agent-entrypoint: dry-run validation passed ==="
  echo "  ATHENA_TARGET:       ${ATHENA_TARGET}"
  echo "  ATHENA_CONFIG_DIR:   ${ATHENA_CONFIG_DIR}"
  echo "  ATHENA_TOOL_REGISTRY: ${ATHENA_TOOL_REGISTRY}"
  echo "  ATHENA_ALLOWLIST:    ${ATHENA_ALLOWLIST}"
  echo "  ATHENA_GT_OUTPUT:    ${ATHENA_GT_OUTPUT}"
  echo "  ATHENA_CAPABILITIES: ${ATHENA_CAPABILITIES:-<none>}"
  echo "  ATHENA_SCENARIO_LABEL: ${ATHENA_SCENARIO_LABEL:-<none>}"
  echo "  OLLAMA_HOST:         ${OLLAMA_HOST}"
  echo "  TARGET_CONFIG:       ${TARGET_CONFIG}"
  exit 0
fi

echo "[athena-agent-entrypoint] Starting OPAR loop..."
echo "  Target: ${ATHENA_TARGET}"
echo "  LLM:    ${OLLAMA_HOST}"
echo "  Output: ${ATHENA_GT_OUTPUT}"

exec python3 -m orchestrator \
  --target "${ATHENA_TARGET}" \
  --config-dir "${ATHENA_CONFIG_DIR}"
