# This Dockerfile won't build anything useful by itself. It's used by build.sh
ARG REGISTRY
FROM ${REGISTRY}/plex/${TARGETPLATFORM}
