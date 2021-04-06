# Plex

Unofficial builds of the official Plex Docker image.

The official Plex image is published only for amd64, these unofficial builds are also published for arm7 and arm64. If you only need amd64 you should use the official image.

See the [official image's documentation](https://hub.docker.com/r/plexinc/pms-docker) for usage details. Tags are created with the Plex version and should mirror the official image's tags.

## Build it yourself

If you want to build locally, you need docker buildx and the host should have qemu installed with binfmt support. 

Set these environment variables:

`IMAGE_NAME` - output image name.
`BUILD_OUTPUT` - `push` or `load`, passed as flag to buildx.

Then run `./build.sh`.
