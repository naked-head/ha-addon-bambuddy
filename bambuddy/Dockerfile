ARG BUILD_FROM
ARG BAMBUDDY_VERSION=1.2.5
FROM ghcr.io/maziggy/bambuddy:${BAMBUDDY_VERSION} AS builder
FROM ${BUILD_FROM}

WORKDIR /app

# Install system dependencies on Alpine
RUN apk add --no-cache \
    build-base \
    py3-opencv \
    ca-certificates \
    curl \
    ffmpeg \
    python3 \
    py3-pip

# Copy requirements and install Python dependencies
COPY --from=builder /app/requirements.txt ./

# Remove opencv-python-headless (replaced by Alpine's py3-opencv)
RUN sed -i 's/opencv-python-headless/# opencv-python-headless/' requirements.txt && \
    pip install --root-user-action=ignore --break-system-packages -r requirements.txt

# Copy application code only — explicitly exclude entrypoint and gosu
COPY --from=builder /app/backend /app/backend
COPY --from=builder /app/static /app/static
COPY --from=builder /app/gcode_viewer /app/gcode_viewer

ENV PYTHONUNBUFFERED=1
ENV DATA_DIR=/app/data
ENV LOG_DIR=/app/logs

# Copy S6 run scripts — must come after app copy
COPY rootfs /
RUN chmod +x /etc/services.d/bambuddy/run /etc/services.d/bambuddy/finish

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