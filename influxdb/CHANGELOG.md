# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- The App documentation now states the upstream license: InfluxDB OSS is MIT,
  same as the packaging in this repository.

## [2.8.0-1] - 2026-07-22

### Added

- First release of the InfluxDB app, based on InfluxDB OSS **2.8.0**.
- Image built on top of the official `influxdb:2.8.0`, with s6-overlay v3
  and bashio installed by hand, same pattern as `bambu-studio-api`.
- Data persisted under `/data` (bolt file + engine), Supervisor-managed.
- Port 8086 exposed for HTTP API and Web UI; `webui` and `watchdog`
  (`/health`) in `config.yaml` instead of Ingress. The old community v1 app
  (`hassio-addons/addon-influxdb`) did Ingress by proxying Chronograf via
  nginx+Lua, but Chronograf no longer exists in v2 and its built-in SPA
  doesn't support a custom base path (open upstream issue since
  2020/2021, never resolved) — DOCS.md documents the Webpage/iframe panel
  alternative.
- `reporting` and `log_level` options.
- Optional initial setup (org/bucket/user/token) via options
  (`init_mode: setup`), or from the Web UI on first boot (`init_mode:
  skip`, default).
- Support for `influx backup` / `influx restore` from inside the
  container.
- Pre-built image published to `ghcr.io/naked-head/ha-app-influxdb-{arch}`
  by `.github/workflows/influxdb-build.yml`, with fallback to a local
  Dockerfile build.
- Supported architectures: amd64, aarch64.

### Fixed

- `DOCS.md` migration "Option B" (direct file copy) now also lists
  `influxd.sqlite` (notebooks/annotations metadata) alongside `influxd.bolt`
  and `engine/`. Confirmed from a real first boot that InfluxDB 2.8.0
  writes this file by default in the same directory as the bolt path
  (`/data/influxd.sqlite`); a copy that skipped it would silently lose
  notebooks and annotations, not the time-series data itself.

[Unreleased]: https://github.com/naked-head/homeassistant-addons/compare/influxdb-v2.8.0-1...HEAD
[2.8.0-1]: https://github.com/naked-head/homeassistant-addons/releases/tag/influxdb-v2.8.0-1