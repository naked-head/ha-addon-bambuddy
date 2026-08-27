# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
#
# Bambu Studio API – Home Assistant add-on.
#
# Two-stage build:
#   1) `build`: clone upstream maziggy/orca-slicer-api (bambuddy/profile-resolver
#      branch), download the Bambu Studio AppImage, extract it, and `npm run
#      build` the Node wrapper.
#   2) Runtime: Ubuntu 22.04 + Node 22 + s6-overlay + bashio. Stays on 22.04
#      because BambuStudio links against libwebkit2gtk-4.0, which Ubuntu 24.04
#      no longer ships.
#
# amd64 only: BambuLab does not publish an official ARM64 AppImage and the
# upstream Dockerfile.bambu-studio fails fast on arm64 — we mirror that here.
ARG BAMBU_VERSION=02.08.02.61
ARG UPSTREAM_REF=bambuddy/profile-resolver
# ---------------------------------------------------------------------------
# Stage 1: build the Node wrapper + extract the Bambu Studio AppImage
# ---------------------------------------------------------------------------
FROM node:22-bookworm AS build
ARG BAMBU_VERSION
ARG UPSTREAM_REF
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo "ARM64 not supported — BambuStudio has no official ARM64 AppImage."; \
        exit 1; \
    fi
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git curl ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${UPSTREAM_REF}" \
        https://github.com/maziggy/orca-slicer-api.git .
RUN echo "Downloading BambuStudio v${BAMBU_VERSION}..." \
    && APPIMAGE_URL=$(curl -s "https://api.github.com/repos/bambulab/BambuStudio/releases/tags/v${BAMBU_VERSION}" \
        | jq -r '.assets[].browser_download_url' \
        | grep -i 'ubuntu' \
        | grep '\.AppImage$' \
        | head -n1) \
    && if [ -z "${APPIMAGE_URL}" ]; then \
        echo "ERROR: No Linux AppImage found for v${BAMBU_VERSION}. Check https://github.com/bambulab/BambuStudio/releases/tag/v${BAMBU_VERSION}"; \
        exit 1; \
    fi \
    && echo "URL: ${APPIMAGE_URL}" \
    && curl -fL -o bambu.AppImage "${APPIMAGE_URL}" \
    && chmod +x bambu.AppImage \
    && ./bambu.AppImage --appimage-extract \
    && rm bambu.AppImage
RUN npm ci && npm run build
# ---------------------------------------------------------------------------
# Stage 2: runtime image (Ubuntu 24.04 + Node 22 + s6-overlay + bashio)
# ---------------------------------------------------------------------------
FROM ubuntu:24.04
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG BASHIO_VERSION=v0.16.2
ARG TARGETARCH
LABEL org.opencontainers.image.title="Home Assistant App: Bambu Studio API"
LABEL org.opencontainers.image.description="Headless Bambu Studio CLI as a REST API. Sidecar for Bambuddy server-side slicing."
LABEL org.opencontainers.image.source="https://github.com/naked-head/homeassistant-addons"
LABEL org.opencontainers.image.authors="naked-head"
LABEL org.opencontainers.image.licenses="MIT AND AGPL-3.0-only"
# Runtime dependencies: BambuStudio's webkit2gtk-4.0 stack + Node 22 + the
# small set of tools we need for s6/bashio bootstrap.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg xz-utils jq tini \
        libgl1 libgl1-mesa-dri libegl1 libopengl0 libglu1-mesa libosmesa6 \
        libsm6 libice6 libmspack0 libsoup2.4-1 \
        libgtk-3-0 \
        libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
        libwebkit2gtk-4.1-0 \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
         | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
         > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && update-ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# s6-overlay v3 (the HA add-on supervision layer)
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
        amd64) S6_ARCH=x86_64 ;; \
        arm64) S6_ARCH=aarch64 ;; \
        *)     S6_ARCH=x86_64 ;; \
    esac; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar -Jxpf - -C /; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
        | tar -Jxpf - -C /
# bashio (HA add-on config helper used in the s6 run script)
RUN set -eux; \
    mkdir -p /tmp/bashio; \
    curl -fsSL "https://github.com/hassio-addons/bashio/archive/${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - --strip-components=1 -C /tmp/bashio; \
    mv /tmp/bashio/lib /usr/lib/bashio; \
    ln -s /usr/lib/bashio/bashio /usr/bin/bashio; \
    rm -rf /tmp/bashio
# s6-overlay v3 installs `with-contenv` at /command/with-contenv, but the
# conventional HA add-on shebang line `#!/usr/bin/with-contenv bashio`
# (used by every HA base-* image) expects it at /usr/bin/with-contenv.
# Without this symlink, s6-supervise fails to spawn the run script with
# "No such file or directory" because the kernel can't resolve the
# interpreter path in the shebang.
RUN ln -s /command/with-contenv /usr/bin/with-contenv
# Wrapper build output + extracted BambuStudio AppImage
COPY --from=build /src/dist/src      /app/dist
COPY --from=build /src/node_modules  /app/node_modules
COPY --from=build /src/package.json  /app/package.json
COPY --from=build /src/squashfs-root /app/squashfs-root
# The wrapper reads these. ORCASLICER_PATH is the slicer-binary env var even
# on the Bambu Studio variant (the wrapper is slicer-agnostic).
# DATA_PATH=/data is bind-mounted to addon_configs/<slug>/data via the run
# script's symlink, so profiles persist.
ENV PORT=3000 \
    ORCASLICER_PATH=/app/squashfs-root/AppRun \
    DATA_PATH=/data \
    BUNDLED_PROFILES_PATH=/app/squashfs-root/resources/profiles/BBL \
    NODE_ENV=production
# HA add-on s6 service plumbing
COPY rootfs /
RUN chmod a+x /etc/services.d/bambu-studio-api/run \
              /etc/services.d/bambu-studio-api/finish
EXPOSE 3000
ENTRYPOINT ["/init"]
