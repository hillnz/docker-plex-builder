#!/usr/bin/env bash

set -e

IMAGE_NAME=jonoh/plex

tmp_dir=$(mktemp -d)
trap 'rm -rf $tmp_dir' EXIT

function build {
    dockerfile="$1"
    target_platform="$2"d
    plex_platform="$3"

    # HACK Download deb and host this to Plex image. Works around apparent qemu bug (https://github.com/docker/buildx/issues/328)
    downloader_image="downloader-$plex_platform"
    trap 'docker stop $downloader_image || true && docker rmi $downloader_image || true' ERR RETURN
    docker build --progress plain -t "$downloader_image" --build-arg "PLEX_BUILD=$plex_platform" -f Dockerfile.downloader .
    docker run -d --rm --name "$downloader_image" -P "$downloader_image"
    port=$(docker port "$downloader_image" | sed 's/.*://')

    echo "Building for $target_platform using $dockerfile"
    cd pms-docker
    docker buildx build \
        --build-arg "URL=http://172.17.0.1:$port/plexmediaserver.deb" \
        --platform "$target_platform" \
        --tag "plex/$target_platform" \
        -f "$dockerfile" \
        --cache-to "type=local,dest=$tmp_dir" \
        --progress plain .
    cd -
}

build Dockerfile linux/amd64 linux-x86_64 &
build Dockerfile.armv7 linux/arm/v7 linux-armv7hf_neon &
build Dockerfile.arm64 linux/arm64 linux-aarch64 &
wait
