# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-dockerfile
#
# BamBuddy — Home Assistant App.
#
# Builds on top of the official upstream image (Debian trixie / python:3.13-slim,
# multi-arch amd64+arm64) instead of a HA base image, layering s6-overlay v3 and
# bashio on by hand — the same pattern the InfluxDB App uses.
#
# Why this changed in 1.0.18: the previous build re-installed upstream's
# requirements.txt on Alpine and swapped opencv-python-headless for Alpine's
# py3-opencv. That package targets the Alpine branch's own interpreter
# (python3~3.12 on alpine3.21) while the app ran on the base-python image's
# 3.13, so cv2 landed in /usr/lib/python3.12/site-packages — an interpreter
# nothing used. backend/app/services/plate_detection.py catches the resulting
# ImportError and disables the feature at INFO level, so the only symptom was
# a plate-detection toggle that refused to turn on. See issue #9.
#
# On the upstream image OpenCV comes from the manylinux wheel upstream itself
# installs and tests, and there is no dependency resolution left for us to get
# wrong.
ARG BAMBUDDY_VERSION=1.2.5.5
FROM ghcr.io/maziggy/bambuddy:${BAMBUDDY_VERSION}

ARG S6_OVERLAY_VERSION=3.2.0.2
ARG BASHIO_VERSION=v0.16.2
ARG TARGETARCH

LABEL org.opencontainers.image.title="Home Assistant App: BamBuddy"
LABEL org.opencontainers.image.description="Self-hosted command center for Bambu Lab printers. No cloud required."
LABEL org.opencontainers.image.source="https://github.com/naked-head/homeassistant-addons"
LABEL org.opencontainers.image.authors="naked-head"
LABEL org.opencontainers.image.licenses="MIT AND AGPL-3.0-only"

WORKDIR /app

# jq and xz-utils bootstrap s6-overlay and bashio below; curl and
# ca-certificates are already in the upstream image. jq also stays for
# runtime — bashio shells out to it on every config read, and the run
# script calls bashio::jq directly.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        jq \
        xz-utils \
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

# bashio (the HA add-on config helper used in the s6 run script)
RUN set -eux; \
    mkdir -p /tmp/bashio; \
    curl -fsSL "https://github.com/hassio-addons/bashio/archive/${BASHIO_VERSION}.tar.gz" \
        | tar -xzf - --strip-components=1 -C /tmp/bashio; \
    mv /tmp/bashio/lib /usr/lib/bashio; \
    ln -s /usr/lib/bashio/bashio /usr/bin/bashio; \
    rm -rf /tmp/bashio

# s6-overlay v3 installs `with-contenv` at /command/with-contenv, but the
# conventional HA add-on shebang line "#!/usr/bin/with-contenv bashio" (used
# by every HA base-* image) expects it at /usr/bin/with-contenv. Without
# this symlink, s6-supervise fails to spawn the run script with "No such
# file or directory" because the kernel can't resolve the interpreter path
# in the shebang.
RUN ln -s /command/with-contenv /usr/bin/with-contenv

# Already set by the upstream image; repeated here so the App's expectations
# are explicit and survive an upstream change. The run script replaces both
# directories with symlinks into /data at startup.
ENV PYTHONUNBUFFERED=1
ENV DATA_DIR=/app/data
ENV LOG_DIR=/app/logs

# HA add-on s6 service plumbing
COPY rootfs /
RUN chmod +x /etc/services.d/bambuddy/run \
             /etc/services.d/bambuddy/finish

# Web UI
EXPOSE 8000/tcp
EXPOSE 3000/tcp
EXPOSE 3002/tcp
EXPOSE 2021/udp
EXPOSE 8883/tcp
EXPOSE 6000/tcp
EXPOSE 322/tcp
EXPOSE 990/tcp
EXPOSE 2024/tcp
EXPOSE 2025/tcp
EXPOSE 2026/tcp
EXPOSE 50000-50029/tcp

# The upstream image ships its own ENTRYPOINT (PUID/PGID normalisation plus a
# gosu privilege drop) and a CMD that starts uvicorn directly. We replace the
# entrypoint with s6's /init, and CMD has to be blanked explicitly: s6-overlay
# v3 runs an inherited CMD as the container's main program once stage 2 is up,
# which would start a second uvicorn on port 8000 next to the one our s6
# service starts. Clearing it leaves /etc/services.d/bambuddy as the only
# thing that launches the app.
ENTRYPOINT ["/init"]
CMD []