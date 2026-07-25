# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.14]

- Switched to pre-built images published on GHCR (amd64 + aarch64)
- Install and update no longer compile the image locally, fixing out-of-memory hangs on low-RAM ARM boards (e.g. Raspberry Pi 4)
- Local Dockerfile build retained as automatic fallback

## [1.0.13] - 2026-07-24

### Changed
- Updated BamBuddy to 1.2.5 (from 0.2.4.9). Upstream changed its versioning scheme — the leading digit went from 0 to 1, but this is a normal successor release on the same code base, not a rewrite.

### Notes
Upstream release notes: https://github.com/maziggy/bambuddy/releases/tag/1.2.5

Behaviour changes worth knowing about before updating:
- Bed levelling, flow calibration and nozzle-offset calibration are now three-way Off / Auto / On, with new prints defaulting to Auto. Existing queued prints are migrated automatically.
- Bambu Cloud sign-in state is now detected correctly. If you linked your Bambu account before enabling authentication, you may need to re-link once from the Profiles page.
- P1S / P1P AMS drying is screen-only — upstream removed Start/Stop because P1 firmware discards the command.
- REST smart plugs (Shelly): if your Energy JSON Path points at a lifetime counter, move it to the new "Energy JSON Path (lifetime)" field.
- Take a fresh backup after updating — backups made on older builds carry a degraded schema.

## [1.0.12]

- **Fixed a config upgrade issue**: `enable_share`, `enable_media`, and `certfile` (added in 1.0.11) were required fields in the schema, which broke saving the configuration for anyone who updated from 1.0.10 or earlier without those keys already present. They are now optional (`bool?`/`str?`); the App already handled their absence gracefully at runtime (features simply stay disabled), it was only the schema stopping the save. Applied the same fix preemptively to `enable_ipv6`, introduced below, for the same reason.
- **Removed the Supervisor `watchdog`** added in 1.0.11. On at least one system it caused repeated false-positive restarts every ~2 minutes, unrelated to BamBuddy's actual health — traced to the health-check connection silently timing out rather than failing fast. Not worth the risk for the benefit it provided; may reconsider in the future with a more targeted implementation.
- **Added `enable_ipv6` option (opt-in, off by default).** 1.0.11 changed the default bind address from `0.0.0.0` to `::`, intended to add IPv6 support while keeping IPv4 working (a `::` bind is normally a superset of `0.0.0.0` on Linux). In practice, this stopped accepting IPv4 connections entirely on at least one system — even with IPv6 disabled at the kernel level (`net.ipv6.bindv6only=0`), pointing to a uvicorn/asyncio-level socket behavior rather than an OS setting we can check for. Given the severity of the failure mode (complete loss of access, including via reverse proxies/tunnels), IPv6 is now **off by default** (`0.0.0.0`, matching every version before 1.0.11) and only enabled if `enable_ipv6` is explicitly turned on. If enabling it makes BamBuddy unreachable, disable it again from the Configuration tab in YAML mode and restart — this always restores access.

### Note on 1.0.11

Shortly after the 1.0.11 release, a bug was found in the automatic timezone detection: the code piped `curl`'s output into `bashio::jq`, but `bashio::jq` doesn't read from stdin — it crashed the App on every start (`jq: parse error: Invalid numeric literal at line 2, column 0`), triggering a restart loop. This was fixed directly on `main` without a version bump; if you installed or updated during that window and are still seeing this error, use **Repository → Check for updates** followed by **Rebuild** to pick up the fix, or update to 1.0.12.

## [1.0.11]

### ⚠️ BREAKING CHANGES — action required after updating

- **`trusted_frame_origins` changed from a single string to a list.** If you already had this option configured (any non-empty value), **the App will fail to start after this update** until you fix it manually:
  1. Go to the App's **Configuration** tab.
  2. Switch to **YAML mode** (the `{}` icon, top right of the config editor).
  3. Change `trusted_frame_origins` from a string to a list — one origin per line, e.g.:
     ```yaml
     trusted_frame_origins:
       - "http://192.168.1.100:8123"
       - "https://ha.yourdomain.com"
     ```
  4. Save and restart the App.
  - If you never configured this option, no action is needed.

- **`bambuddy_external_roots` has been removed**, replaced by two simple toggles: `enable_share` and `enable_media`. If you had this option configured with any path (e.g. `/share/3dprints`), **that configuration is silently dropped by this update** — it will not carry over automatically, and File Manager's external folders will stop working until you re-enable them:
  1. Go to the App's **Configuration** tab.
  2. Enable `enable_share` and/or `enable_media` depending on which folder(s) you used.
  3. Save and restart the App.
  4. In BamBuddy, go to **File Manager → Add external folder** and re-add `/share` or `/media`.

### Other changes

- Bind on `::` instead of `0.0.0.0` so BamBuddy is reachable over IPv6 in addition to IPv4 by @grischard in https://github.com/naked-head/homeassistant-addons/pull/10
- Detect timezone automatically from Home Assistant at startup instead of a manual `timezone` option (falls back to UTC if it can't be retrieved) by @grischard in https://github.com/naked-head/homeassistant-addons/pull/11
- `use_system_trust_store` now actually installs the certificate into the container's trust store (new `certfile` option), instead of only setting an environment variable with no effect.
- Added a Supervisor `watchdog` so the App restarts automatically if BamBuddy stops responding.
- Added `ca-certificates` package to the image (required for the certificate installation above).

### New Contributors

- @grischard made their first contribution in https://github.com/naked-head/homeassistant-addons/pull/10

**Full Changelog**: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.10...bambuddy-v1.0.11

## [1.0.10]

- Fixed a crash in `bambuddy_external_roots` handling: the `run` script called `bashio::addon_config`, which doesn't exist, instead of reading `/data/options.json` directly.

## [1.0.9]

- Fixed `trusted_frame_origins` disappearing from the UI editor after an add-on restart (removed empty-string default from `options`, kept it as a truly optional `schema` field). Applied the same fix to `bind_address`, which had the same latent issue.
- Added `ha_url` / `ha_token` options for Home Assistant integration. Enabled `homeassistant_api: true` so both default automatically to the Supervisor's own Core API and token when left unset.
- Added `database_url` option to use an external PostgreSQL database instead of the built-in SQLite database.
- Added `bambuddy_external_roots` option to allow registering external File Manager folders under `/share` or `/media`. Mapped `share:rw` and `media:rw` in `config.yaml` to support this.
- Added `use_system_trust_store` option to trust self-signed certificates.
- Pinned the upstream BamBuddy builder image to an explicit version tag (`BAMBUDDY_VERSION` build arg) instead of `:latest`, to guarantee the intended BamBuddy version is actually built regardless of Docker layer caching.

## [1.0.8]

- Updated BamBuddy to v0.2.4.9
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.9

## [1.0.7]

- Updated BamBuddy to v0.2.4.8
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.8

## [1.0.6]

- Updated BamBuddy to v0.2.4.7
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.7

## [1.0.5]

- Updated BamBuddy to v0.2.4.6
- Narrowed FTP passive port range from 50000-50100 to 50000-50029
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.6

## [1.0.4]

- Added `trusted_frame_origins` configuration option for sidebar embedding without Cloudflare

## [1.0.3]

- Updated BamBuddy to v0.2.4.5
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.5

## [1.0.2]

- Updated BamBuddy to v0.2.4.4
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.4

## [1.0.1]

- Added Virtual Printer certificate instructions to README

## [1.0.0]

- Initial release of the Home Assistant add-on
- Based on BamBuddy v0.2.4.3
- Supports amd64 and aarch64 architectures
- Persistent storage via HA Supervisor data volume
- Configurable bind address for multi-IP setups (e.g. IP alias to avoid port conflicts)
- Configurable timezone and log level

[Unreleased]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.14...HEAD
[1.0.14]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.13...bambuddy-v1.0.14
[1.0.13]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.12...bambuddy-v1.0.13
[1.0.12]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.11...bambuddy-v1.0.12
[1.0.11]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.10...bambuddy-v1.0.11
[1.0.10]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.9...bambuddy-v1.0.10
[1.0.9]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.8...bambuddy-v1.0.9
[1.0.8]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.7...bambuddy-v1.0.8
[1.0.7]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy?before=bambuddy-v1.0.8
[1.0.6]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.5]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.4]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.3]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.2]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.1]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy
[1.0.0]: https://github.com/naked-head/homeassistant-addons/commits/main/bambuddy