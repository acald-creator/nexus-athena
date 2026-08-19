#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUSH=false
KEYLESS=false
REGISTRY="${REGISTRY:-phoenixvlabs}"
TARGET="${TARGET:-athena-core}"
while [[ $# -gt 0 ]]; do
  case $1 in
    --push) PUSH=true; shift ;;
    --keyless) KEYLESS=true; shift ;;
    --registry) REGISTRY="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done
VERSION="$(git -C "$REPO_ROOT" log -1 --pretty=%h 2>/dev/null || echo dev)"
BUILD_TS="$(date -u +%FT%TZ)"
IMAGE_TAG="${IMAGE_TAG:-$REGISTRY/nexus-athena:$VERSION}"
IMAGE_LATEST="$REGISTRY/nexus-athena:latest"
echo "=== Build + Sign + SBOM ==="
echo "  Target:  $TARGET"
echo "  Tag:     $IMAGE_TAG"
echo "  Push:    $PUSH"
echo ""
echo "[1/4] Building..."
"$SCRIPT_DIR/build-athena-image.sh" "$TARGET"
docker tag "$REGISTRY/nexus-athena:latest" "$IMAGE_TAG"
echo "[2/4] SBOM (syft)..."
SBOM_FILE="$REPO_ROOT/nexus-athena-$VERSION.spdx.json"
syft "$IMAGE_TAG" -o spdx-json="$SBOM_FILE"
echo "  -> $SBOM_FILE"
echo "[3/4] Scan (grype)..."
SCAN_FILE="$REPO_ROOT/nexus-athena-$VERSION.grype.json"
grype "$IMAGE_TAG" -o json > "$SCAN_FILE" 2>/dev/null || true
echo "  -> $SCAN_FILE"
if [ "$PUSH" = true ]; then
  echo "[4/4] Push + Sign..."
  docker push "$IMAGE_TAG"
  docker push "$IMAGE_LATEST"
  if [ "$KEYLESS" = true ]; then
    cosign sign --yes "$IMAGE_TAG"
    cosign sign --yes "$IMAGE_LATEST"
  elif [ -n "${COSIGN_PRIVATE_KEY:-}" ]; then
    cosign sign --yes --key "$COSIGN_PRIVATE_KEY" -a commit="$VERSION" "$IMAGE_TAG"
    cosign sign --yes --key "$COSIGN_PRIVATE_KEY" -a commit="$VERSION" "$IMAGE_LATEST"
  else
    echo "  WARNING: No signing key set."
  fi
  cosign attach sbom --sbom "$SBOM_FILE" "$IMAGE_TAG" 2>/dev/null || true
else
  echo "[4/4] Local only (use --push to publish)"
fi
echo ""
echo "Done: $IMAGE_TAG"
echo "SBOM: $SBOM_FILE"
echo "Scan: $SCAN_FILE"
