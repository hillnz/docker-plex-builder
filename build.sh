#!/usr/bin/env bash

set -e

# HACK hardcode major version 1 as renovate only supports 3 version parts
# renovate: datasource=docker depName=plexinc/pms-docker versioning=regex:^1\.(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+).+
PLEX_VERSION=1.43.0.10492-121068a07
IMAGE_NAME="${IMAGE_NAME:-jonoh/plex}"
DOCKER_HOST=172.17.0.1
BUILD_OUTPUT="${BUILD_OUTPUT:-load}"

function docker_port {
    container_name="$1"
    docker port "$container_name" | head -n1 | sed 's/.*://'
}

# Use private registry for intermediate builds; buildx can't see local images
docker run --rm -d -P --name plex_registry registry
registry="$DOCKER_HOST:$(docker_port plex_registry)"

# Private builder instance, to allow us to configure our registry
builder_config=/tmp/plex_builder.toml
cat <<EOF >/$builder_config
[registry."$registry"]
    http = true
    insecure = true
EOF
docker buildx create --name plex_builder --config "$builder_config"
docker buildx inspect --bootstrap plex_builder

trap 'docker rm -f plex_registry && docker buildx rm plex_builder' EXIT

function build {
    dockerfile="$1"
    target_platform="$2"
    plex_platform="$3"

    # HACK Download deb and host this to Plex image. Works around apparent qemu bug (https://github.com/docker/buildx/issues/328)
    downloader_image="downloader-$plex_platform"
    trap 'docker rm -f $downloader_image || true && docker rmi $downloader_image || true' ERR RETURN
    docker buildx build \
        --build-arg "PLEX_BUILD=$plex_platform" \
        --build-arg "PLEX_VERSION=$PLEX_VERSION" \
        --builder plex_builder \
        --file Dockerfile.downloader \
        --load \
        --progress plain \
        --tag "$downloader_image" \
        .
    docker run -d --rm --name "$downloader_image" -P "$downloader_image"
    port=$(docker_port "$downloader_image")

    echo "Building for $target_platform using $dockerfile"
    cd pms-docker
    docker buildx build \
        --build-arg "URL=http://$DOCKER_HOST:$port/plexmediaserver.deb" \
        --builder plex_builder \
        --file "$dockerfile" \
        --platform "$target_platform" \
        --progress plain \
        --push \
        --tag "$registry/plex/$target_platform" \
        .
    cd -
}

build Dockerfile linux/amd64 linux-x86_64 &
build Dockerfile.armv7 linux/arm/v7 linux-armv7hf_neon &
build Dockerfile.arm64 linux/arm64 linux-aarch64 &
wait

# Finally, combine into single image manifest and push
OUTPUT_FLAG=$([[ "$BUILD_OUTPUT" == "push" ]] && echo "--push " || echo "")
# shellcheck disable=SC2086
docker buildx build \
    --build-arg "REGISTRY=$registry" \
    --builder plex_builder \
    --platform linux/amd64,linux/arm/v7,linux/arm64 \
    $OUTPUT_FLAG\
    --tag "$IMAGE_NAME:$PLEX_VERSION" \
    --tag "$IMAGE_NAME:latest" \
    .
