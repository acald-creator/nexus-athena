#!/usr/bin/env bash
# build-athena-image.sh — Build nexus-athena image with athena-agents included.
#
# Usage:
#   ./scripts/build-athena-image.sh              # Build athena-core
#   ./scripts/build-athena-image.sh full         # Build athena-full
#
# Requires athena-agents repo at $ATHENA_AGENTS_PATH (default: ../athena-agents)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET="${1:-athena-core}"
ATHENA_AGENTS_PATH="${ATHENA_AGENTS_PATH:-$(cd "$REPO_ROOT/../athena-agents" && pwd)}"
IMAGE_TAG="${IMAGE_TAG:-phoenixvlabs/nexus-athena:latest}"

if [[ ! -d "$ATHENA_AGENTS_PATH" ]]; then
  echo "Error: athena-agents not found at $ATHENA_AGENTS_PATH" >&2
  exit 1
fi

echo "Building nexus-athena (target: $TARGET)"
echo "  athena-agents: $ATHENA_AGENTS_PATH"
echo "  image tag:     $IMAGE_TAG"

# Temp build context merging both repos
BUILD_CTX=$(mktemp -d)
trap "rm -rf $BUILD_CTX" EXIT

cp "$REPO_ROOT/Dockerfile" "$BUILD_CTX/"
cp -r "$REPO_ROOT/scripts" "$BUILD_CTX/scripts"
cp -r "$REPO_ROOT/config" "$BUILD_CTX/config" 2>/dev/null || true

mkdir -p "$BUILD_CTX/athena-agents"
cp "$ATHENA_AGENTS_PATH/Cargo.toml" "$BUILD_CTX/athena-agents/"
cp "$ATHENA_AGENTS_PATH/Cargo.lock" "$BUILD_CTX/athena-agents/" 2>/dev/null || touch "$BUILD_CTX/athena-agents/Cargo.lock"
cp -r "$ATHENA_AGENTS_PATH/crates" "$BUILD_CTX/athena-agents/crates"
cp "$ATHENA_AGENTS_PATH/pyproject.toml" "$BUILD_CTX/athena-agents/"
cp -r "$ATHENA_AGENTS_PATH/orchestrator" "$BUILD_CTX/athena-agents/orchestrator"
cp -r "$ATHENA_AGENTS_PATH/eval" "$BUILD_CTX/athena-agents/eval" 2>/dev/null || mkdir -p "$BUILD_CTX/athena-agents/eval"

VERSION=$(git -C "$REPO_ROOT" log -1 --pretty=%h 2>/dev/null || echo "dev")
BUILD_TS=$(date '+%F_%H:%M:%S')

docker buildx build \
  --target "$TARGET" \
  --build-arg VERSION="$VERSION" \
  --build-arg BUILD_TIMESTAMP="$BUILD_TS" \
  -t "$IMAGE_TAG" \
  "$BUILD_CTX"

echo "Built: $IMAGE_TAG (target: $TARGET)"
