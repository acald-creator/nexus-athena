#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-standard}"
COMPOSE_FILE="deploy/compose/athena-profiles.yml"
ATHENA_IMAGE="${ATHENA_IMAGE:-phoenixvlabs/nexus-athena:latest}"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "missing compose file: ${COMPOSE_FILE}" >&2
  exit 1
fi

case "${PROFILE}" in
  standard)
    export ATHENA_IMAGE
    docker compose -f "${COMPOSE_FILE}" up -d athena.standard
    docker compose -f "${COMPOSE_FILE}" ps
    ;;
  packet-lab)
    export ATHENA_IMAGE
    docker compose --profile packet-lab -f "${COMPOSE_FILE}" up -d athena.packet-lab
    docker compose --profile packet-lab -f "${COMPOSE_FILE}" ps
    ;;
  down)
    export ATHENA_IMAGE
    docker compose --profile packet-lab -f "${COMPOSE_FILE}" down
    ;;
  *)
    echo "usage: $0 {standard|packet-lab|down}" >&2
    exit 1
    ;;
esac
