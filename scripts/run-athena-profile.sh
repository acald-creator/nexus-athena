#!/usr/bin/env bash
# run-athena-profile.sh — Start an Athena runtime profile.
#
# Usage:
#   ./scripts/run-athena-profile.sh standard          # Basic red-team (default)
#   ./scripts/run-athena-profile.sh packet-lab        # Packet capture capabilities
#   ./scripts/run-athena-profile.sh exploit-lab       # Full exploit capabilities
#   ./scripts/run-athena-profile.sh agent <target>    # LLM-driven OPAR mode
#   ./scripts/run-athena-profile.sh agent-ics <target> # LLM agent + ICS capabilities
#   ./scripts/run-athena-profile.sh down              # Tear down all profiles
#   ./scripts/run-athena-profile.sh status            # Show running containers

set -euo pipefail

PROFILE="${1:-standard}"
COMPOSE_FILE="deploy/compose/athena-profiles.yml"
ATHENA_IMAGE="${ATHENA_IMAGE:-phoenixvlabs/nexus-athena:latest}"

export ATHENA_IMAGE

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Error: missing compose file: ${COMPOSE_FILE}" >&2
  echo "Run this script from the repository root." >&2
  exit 1
fi

case "${PROFILE}" in
  standard)
    echo "Starting Athena standard profile..."
    docker compose -f "${COMPOSE_FILE}" up -d athena.standard
    ;;
  packet-lab)
    echo "Starting Athena packet-lab profile (NET_ADMIN + NET_RAW)..."
    docker compose --profile packet-lab -f "${COMPOSE_FILE}" up -d athena.packet-lab
    ;;
  exploit-lab)
    echo "Starting Athena exploit-lab profile (NET_ADMIN + NET_RAW + SYS_PTRACE)..."
    docker compose --profile exploit-lab -f "${COMPOSE_FILE}" up -d athena.exploit-lab
    ;;
  agent)
    TARGET="${2:-${ATHENA_TARGET:-}}"
    export ATHENA_TARGET="${TARGET}"
    if [[ -z "${ATHENA_TARGET}" ]]; then
      echo "Usage: $0 agent <target>" >&2
      echo "  Available targets:" >&2
      ls config/targets/*.toml 2>/dev/null | sed 's|config/targets/||;s|\.toml||;s|^|    |' >&2
      exit 1
    fi
    echo "Starting Athena agent profile (LLM OPAR mode)..."
    echo "  Target:      ${ATHENA_TARGET}"
    echo "  OLLAMA_HOST: ${OLLAMA_HOST:-http://host.docker.internal:11434}"
    echo "  Config:      ${ATHENA_CONFIG_PATH:-./config}"
    docker compose --profile agent -f "${COMPOSE_FILE}" up -d athena.agent
    ;;
  agent-ics)
    TARGET="${2:-${ATHENA_TARGET:-}}"
    export ATHENA_TARGET="${TARGET}"
    if [[ -z "${ATHENA_TARGET}" ]]; then
      echo "Usage: $0 agent-ics <target>" >&2
      echo "  Available targets:" >&2
      ls config/targets/*.toml 2>/dev/null | sed 's|config/targets/||;s|\.toml||;s|^|    |' >&2
      exit 1
    fi
    echo "Starting Athena agent-ics profile (LLM OPAR + ICS_WRITE + CAN_INJECT)..."
    echo "  Target:         ${ATHENA_TARGET}"
    echo "  OLLAMA_HOST:    ${OLLAMA_HOST:-http://host.docker.internal:11434}"
    echo "  Capabilities:   ICS_WRITE, CAN_INJECT"
    docker compose --profile agent-ics -f "${COMPOSE_FILE}" up -d athena.agent-ics
    ;;
  detection)
    echo "Starting Suricata detection on athena_lab network..."
    docker compose --profile detection -f "${COMPOSE_FILE}" up -d suricata.sensor suricata.forwarder
    echo "Suricata capturing on athena_lab. Logs in suricata_logs volume."
    echo "View alerts: docker logs athena-suricata-forwarder"
    ;;
  down)
    echo "Tearing down all Athena profiles..."
    docker compose --profile packet-lab --profile exploit-lab --profile agent --profile agent-ics --profile targets --profile detection \
      -f "${COMPOSE_FILE}" down
    ;;
  status)
    docker compose --profile packet-lab --profile exploit-lab --profile agent --profile agent-ics --profile targets --profile detection \
      -f "${COMPOSE_FILE}" ps
    ;;
  targets)
    echo "Starting lab targets (Juice Shop)..."
    docker compose --profile targets -f "${COMPOSE_FILE}" up -d juice-shop
    echo "Juice Shop at http://localhost:3001"
    ;;
  *)
    echo "Usage: $0 {standard|packet-lab|exploit-lab|agent <target>|agent-ics <target>|targets|detection|down|status}" >&2
    exit 1
    ;;
esac

echo ""
docker compose --profile packet-lab --profile exploit-lab --profile agent --profile agent-ics --profile targets --profile detection \
  -f "${COMPOSE_FILE}" ps 2>/dev/null || true
