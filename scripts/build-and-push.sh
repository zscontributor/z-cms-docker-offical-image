#!/usr/bin/env bash
# Build every Z-CMS service image from source and push it to Docker Hub,
# multi-arch (linux/amd64 + linux/arm64).
#
# The images are built from the Z-CMS *source* repository (this repo holds only
# the Dockerfiles' consumers — compose + docs). Point the script at a checkout,
# or let it clone one.
#
#   NAMESPACE=zcmsorg TAG=0.1.0 SRC=/path/to/z-cms ./scripts/build-and-push.sh
#   TAG=latest ./scripts/build-and-push.sh          # clones z-cms into ./z-cms-src
#
# Prerequisites:
#   * docker + buildx, with QEMU for the arm64 leg:
#       docker run --privileged --rm tonistiigi/binfmt --install all
#   * docker login  (to Docker Hub, as a member of $NAMESPACE)
#
# Set PUSH=false to build only (no login/push) — a local smoke test.
set -euo pipefail

NAMESPACE="${NAMESPACE:-zcmsorg}"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SRC="${SRC:-./z-cms-src}"
SRC_REPO="${SRC_REPO:-https://github.com/zscontributor/z-cms.git}"
SRC_REF="${SRC_REF:-main}"
PUSH="${PUSH:-true}"

# The five services that share the main multi-stage Dockerfile, plus the
# credential-free plugin sandbox with its own Dockerfile.
SHARED_DF="infrastructure/docker/Dockerfile"
PLUGIN_DF="infrastructure/docker/plugin-runtime.Dockerfile"
SHARED_TARGETS="cms-api worker admin-web site-runtime migrate"

# --- get the source --------------------------------------------------------
if [[ ! -d "$SRC" ]]; then
  echo ">> cloning $SRC_REPO ($SRC_REF) into $SRC"
  git clone --depth 1 --branch "$SRC_REF" "$SRC_REPO" "$SRC"
fi
echo ">> building from source at: $SRC"
echo ">> namespace=$NAMESPACE  tag=$TAG  platforms=$PLATFORMS  push=$PUSH"

# --- buildx builder --------------------------------------------------------
if ! docker buildx inspect zcms-builder >/dev/null 2>&1; then
  docker buildx create --name zcms-builder --driver docker-container --use
else
  docker buildx use zcms-builder
fi

OUTPUT_FLAG="--push"
[[ "$PUSH" == "true" ]] || OUTPUT_FLAG="--output=type=cacheonly"

build() {           # build <image-name> <dockerfile> [target]
  local name="$1" dockerfile="$2" target="${3:-}"
  local ref="docker.io/${NAMESPACE}/${name}"
  echo ">> $ref:$TAG"
  docker buildx build \
    --platform "$PLATFORMS" \
    --file "$SRC/$dockerfile" \
    ${target:+--target "$target"} \
    --tag "${ref}:${TAG}" \
    $( [[ "$TAG" != "latest" ]] && echo --tag "${ref}:latest" ) \
    --label "org.opencontainers.image.source=$SRC_REPO" \
    $OUTPUT_FLAG \
    "$SRC"
}

for t in $SHARED_TARGETS; do
  build "$t" "$SHARED_DF" "$t"
done
build "plugin-runtime" "$PLUGIN_DF"

echo ">> done."
