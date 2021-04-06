#!/usr/bin/env bash

set -e

IMAGE_NAME=jonoh/plex

function build {
    dockerfile="$1"
    target_platform="$2"
    plex_platform="$3"

    # HACK Download deb and host this to Plex image. Works around apparent qemu bug (https://github.com/docker/buildx/issues/328)
    downloader_image="downloader-$plex_platform"
    trap 'docker stop $downloader_image || true && docker rmi $downloader_image || true' ERR RETURN
    docker build --progress plain -t "$downloader_image" --build-arg "PLEX_BUILD=$plex_platform" -f Dockerfile.downloader .
    docker run -d --rm --name "$downloader_image" -P "$downloader_image"

    port=$(docker port "$downloader_image" | sed 's/.*://')
    plex_version=$(docker exec "$downloader_image" cat /PLEX_VERSION)
    docker_tag="${plex_version}-$(echo "$target_platform" | sed -E 's#(linux)|/##g')"

    echo "Building for $target_platform using $dockerfile"
    cd pms-docker
    docker buildx build \
        --build-arg "URL=http://172.17.0.1:$port/plexmediaserver.deb" \
        --platform "$target_platform" \
        --tag "$IMAGE_NAME:$docker_tag" \
        -f "$dockerfile" \
        --load \
        --progress plain .
    cd -
}

build Dockerfile linux/amd64 linux-x86_64 &
build Dockerfile.armv7 linux/arm/v7 linux-armv7hf_neon &
build Dockerfile.arm64 linux/arm64 linux-aarch64 &
wait
