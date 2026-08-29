# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.19] - 2026-08-29

### Added
- The App documentation now states the upstream license: BamBuddy is published under the AGPL-3.0, which entitles you to its source — the link is in `DOCS.md`. The packaging in this repository stays MIT.

### Fixed
- The image's OCI license label declared `MIT`, which described only the packaging. It now says `MIT AND AGPL-3.0-only`, matching what the image actually contains.

### Changed
- Updated BamBuddy to 1.2.5.4 (from 1.2.5.3). A fix-heavy release upstream, with around 90 fixes — the heaviest runs on AMS and K profiles, on archives from prints BamBuddy did not dispatch, and on Spoolman cost attribution. The one substantial feature running through it: a spool now carries a different filament preset per printer model and a K profile per hotend, and every path that configures an AMS slot honours both. Around it sit scheduled AMS drying, Filament Track Switch support, Dutch as the fourteenth interface language, and Home Assistant sensors bound to storage locations. No breaking changes.

  Full upstream release notes: https://github.com/maziggy/bambuddy/releases/tag/v1.2.5.4

  If you are coming from 1.0.12 or earlier (BamBuddy 0.2.4.9), read the 1.0.13 entry below first — all of its upgrade callouts still apply to you.
- Documentation uses "App" throughout, following Home Assistant's 2026.2
  rename of add-ons.

## [1.0.18] - 2026-08-23

### Fixed
- **Plate detection could not be enabled.** The toggle stayed off no matter what, on every version of this App since 1.0.0. The cause was in the image build, not in BamBuddy: the App installed OpenCV from Alpine's `py3-opencv` package, which targets the Alpine branch's own Python (3.12), while the application ran on the base image's Python 3.13. The module was there, just under an interpreter nothing used, and BamBuddy disables plate detection silently when `import cv2` fails. Fixes #9.

  Nothing to do on your side — update and the toggle works. If you had turned on `Require plate clear` as a workaround, you can leave it on: it is a separate safety net and still worth having.

### Changed
- The image is now built on top of the official upstream BamBuddy image instead of a Home Assistant Alpine base, with the add-on supervision layer added on top. Practically: the Python environment is now byte-for-byte the one upstream builds and tests, instead of one reconstructed on a different C library. No configuration changes and no migration — your data, printers and settings are untouched.
- Because the base image changed, the first update after this release re-downloads BamBuddy in full — roughly 500 MB over the wire, against a few megabytes for a normal version bump. On disk the App grows from about 1.6 GB to about 1.9 GB. Later updates go back to pulling only what changed.

## [1.0.17] - 2026-08-15

### Changed
- Updated BamBuddy to 1.2.5.3 (from 1.2.5.2). A feature-and-fix release upstream, with 39 fixes and several new features. No breaking changes. It adds tables and columns, applied automatically on both SQLite and PostgreSQL at first start.

  Full upstream release notes: https://github.com/maziggy/bambuddy/releases/tag/v1.2.5.3

  If you are coming from 1.0.12 or earlier (BamBuddy 0.2.4.9), read the 1.0.13 entry below first — all of its upgrade callouts still apply to you.

### Fixed
- Dropped the `gcode_viewer` copy step from the image build: upstream replaced the vendored PrettyGCode viewer with libvgcode in 1.2.5.3, so the directory no longer exists and the build failed on it.

## [1.0.16] - 2026-08-04

### Changed
- Updated BamBuddy to 1.2.5.2 (from 1.2.5.1). A maintenance release upstream, focused on the camera, timelapse and finish-photo pipeline and on the K-profile / Flow Dynamics screens, plus seven smaller features. No breaking changes. It adds two database columns (a per-virtual-printer AMS-mapping flag and a timelapse baseline on print archives), applied automatically on both SQLite and PostgreSQL at first start.

  Full upstream release notes: https://github.com/maziggy/bambuddy/releases/tag/v1.2.5.2

  If you are coming from 1.0.12 or earlier (BamBuddy 0.2.4.9), read the 1.0.13 entry below first — all of its upgrade callouts still apply to you.
- **⚠️ Breaking change — `share_subfolder` / `media_subfolder` are now lists, renamed `share_subfolders` / `media_subfolders`.** They were introduced one release ago as single text fields; making them lists means you can expose more than one folder per root, and matches how `trusted_frame_origins` already works. Sorry for changing this option twice in short order.
  - **Migration:** if you set a value in 1.0.15, re-enter it as a list entry after updating. Coming from 1.0.14 or earlier, see the 1.0.15 entry below — the guidance there still applies, just add list entries instead of filling a single field.
  - Entries are sanitised before use: a `..` segment is rejected, a redundant `/share/` or `/media/` prefix is now **stripped** rather than used verbatim (1.0.15 warned but still produced `/share/share/...`), and a bare `/share` or `/media` is refused, since exposing a whole root is exactly what these options exist to prevent.
- Both options now appear in the App's main configuration instead of under "unused optional configuration options", so the feature is discoverable without hunting for it.
- `certfile` moved the other way, into the optional section — it only does anything when `use_system_trust_store` is on, and having it in the main list implied it was needed on every install.

## [1.0.15] - 2026-07-28

### Changed
- Updated BamBuddy to 1.2.5.1 (from 1.2.5). A bugfix-only upstream release — no new features, no breaking changes. It adds one database column (file modification times), applied automatically on both SQLite and PostgreSQL at first start.

  Full upstream release notes: https://github.com/maziggy/bambuddy/releases/tag/v1.2.5.1

  If you are coming from 1.0.12 or earlier (BamBuddy 0.2.4.9), read the 1.0.13 entry below first — all of its upgrade callouts still apply to you.

- **⚠️ Breaking change — replaced `enable_share` / `enable_media` (booleans) with `share_subfolder` / `media_subfolder` (strings).** The previous toggles exposed the *entire* `/share` or `/media` folder to BamBuddy's File Manager — since these folders are shared by every App and integration on the HA instance, this meant BamBuddy could see (and, if writable, modify) files belonging to unrelated Apps. The new options scope access to a single named subfolder instead (e.g. `share_subfolder: bambuddy` exposes only `/share/bambuddy`), and there is intentionally no option to expose the whole folder anymore.
  - **Migration — this one needs a manual step.** Your old `enable_share`/`enable_media` setting is *not* carried over: those keys no longer exist, and "the whole folder" has no equivalent in the new options by design. After updating, open the App configuration and fill in the new field.
    - If your files were already in a subfolder of `/share` or `/media` (e.g. `/share/3dprints`), just enter that subfolder's name (`3dprints`) and everything works exactly as before — same path in BamBuddy's File Manager, nothing to move.
    - Only if you kept files directly in the root of `/share` or `/media` do you need to move them into a subfolder first, then register the new path in **File Manager → Add external folder**.
  - The subfolder is created automatically on first start if it doesn't exist.
  - Input is sanitized against `..` path segments; a leading `/share/` or `/media/` typed into the value is logged as a warning rather than silently accepted.

### Fixed
- **BamBuddy's own backups no longer inflate Home Assistant's App backups.** Previously, BamBuddy's internal backup folder lived inside this App's persistent data volume, which Home Assistant's own backup feature snapshots in full — every HA backup taken after that point would also contain every BamBuddy backup made since, growing without bound. BamBuddy's backup folder is now redirected to `/share/bambuddy_backups`, which HA does not include in its own backups by default.

  **What happens to your existing backups.** On the first start after updating, any backups found in the old location are **moved** to `/share/bambuddy_backups` — copied first, then verified file by file, and only then removed from the data volume. This is deliberate: leaving a second copy inside the data volume would keep inflating your HA backups, which is the whole point of the change. You'll see `Migrating existing BamBuddy backups to /share/bambuddy_backups` in the App log when this runs. Nothing to do on your side.

  **If the migration can't be verified** (a copy fails, the disk is full, `/share` is read-only), nothing is deleted: the originals are left in place, renamed to `backups.not-migrated`, and the log shows an error instead. In that case, once you've confirmed `/share/bambuddy_backups` holds everything you care about, delete the leftover folder manually — it is *not* removed automatically, and it will keep bloating your HA backups until you do:

  1. Install the **File Editor** or **Samba** App if you don't already have it.
  2. Browse to the App data folder: `apps/data/<prefix>_bambuddy/bambuddy_data/backups.not-migrated`. The `<prefix>` is a hash that differs on every installation — look for the folder ending in `_bambuddy`.
  3. Compare its contents against `/share/bambuddy_backups`, then delete the `backups.not-migrated` folder.

  If you'd rather keep those old backups, move them somewhere under `/share` or `/media` instead of deleting them — anywhere outside the App's data volume is fine.

## [1.0.14] - 2026-07-25

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

## [1.0.12] - 2026-07-15

- **Fixed a config upgrade issue**: `enable_share`, `enable_media`, and `certfile` (added in 1.0.11) were required fields in the schema, which broke saving the configuration for anyone who updated from 1.0.10 or earlier without those keys already present. They are now optional (`bool?`/`str?`); the App already handled their absence gracefully at runtime (features simply stay disabled), it was only the schema stopping the save. Applied the same fix preemptively to `enable_ipv6`, introduced below, for the same reason.
- **Removed the Supervisor `watchdog`** added in 1.0.11. On at least one system it caused repeated false-positive restarts every ~2 minutes, unrelated to BamBuddy's actual health — traced to the health-check connection silently timing out rather than failing fast. Not worth the risk for the benefit it provided; may reconsider in the future with a more targeted implementation.
- **Added `enable_ipv6` option (opt-in, off by default).** 1.0.11 changed the default bind address from `0.0.0.0` to `::`, intended to add IPv6 support while keeping IPv4 working (a `::` bind is normally a superset of `0.0.0.0` on Linux). In practice, this stopped accepting IPv4 connections entirely on at least one system — even with IPv6 disabled at the kernel level (`net.ipv6.bindv6only=0`), pointing to a uvicorn/asyncio-level socket behavior rather than an OS setting we can check for. Given the severity of the failure mode (complete loss of access, including via reverse proxies/tunnels), IPv6 is now **off by default** (`0.0.0.0`, matching every version before 1.0.11) and only enabled if `enable_ipv6` is explicitly turned on. If enabling it makes BamBuddy unreachable, disable it again from the Configuration tab in YAML mode and restart — this always restores access.

### Note on 1.0.11

Shortly after the 1.0.11 release, a bug was found in the automatic timezone detection: the code piped `curl`'s output into `bashio::jq`, but `bashio::jq` doesn't read from stdin — it crashed the App on every start (`jq: parse error: Invalid numeric literal at line 2, column 0`), triggering a restart loop. This was fixed directly on `main` without a version bump; if you installed or updated during that window and are still seeing this error, use **Repository → Check for updates** followed by **Rebuild** to pick up the fix, or update to 1.0.12.

## [1.0.11] - 2026-07-14

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

## [1.0.10] - 2026-07-12

- Fixed a crash in `bambuddy_external_roots` handling: the `run` script called `bashio::addon_config`, which doesn't exist, instead of reading `/data/options.json` directly.

## [1.0.9] - 2026-07-12

- Fixed `trusted_frame_origins` disappearing from the UI editor after an add-on restart (removed empty-string default from `options`, kept it as a truly optional `schema` field). Applied the same fix to `bind_address`, which had the same latent issue.
- Added `ha_url` / `ha_token` options for Home Assistant integration. Enabled `homeassistant_api: true` so both default automatically to the Supervisor's own Core API and token when left unset.
- Added `database_url` option to use an external PostgreSQL database instead of the built-in SQLite database.
- Added `bambuddy_external_roots` option to allow registering external File Manager folders under `/share` or `/media`. Mapped `share:rw` and `media:rw` in `config.yaml` to support this.
- Added `use_system_trust_store` option to trust self-signed certificates.
- Pinned the upstream BamBuddy builder image to an explicit version tag (`BAMBUDDY_VERSION` build arg) instead of `:latest`, to guarantee the intended BamBuddy version is actually built regardless of Docker layer caching.

## [1.0.8] - 2026-07-07

- Updated BamBuddy to v0.2.4.9
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.9

## [1.0.7] - 2026-06-28

- Updated BamBuddy to v0.2.4.8
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.8

## [1.0.6] - 2026-06-14

- Updated BamBuddy to v0.2.4.7
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.7

## [1.0.5] - 2026-06-09

- Updated BamBuddy to v0.2.4.6
- Narrowed FTP passive port range from 50000-50100 to 50000-50029
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.6

## [1.0.4] - 2026-06-08

- Added `trusted_frame_origins` configuration option for sidebar embedding without Cloudflare

## [1.0.3] - 2026-06-03

- Updated BamBuddy to v0.2.4.5
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.5

## [1.0.2] - 2026-05-31

- Updated BamBuddy to v0.2.4.4
- Full release notes: https://github.com/maziggy/bambuddy/releases/tag/v0.2.4.4

## [1.0.1] - 2026-05-26

- Added Virtual Printer certificate instructions to README

## [1.0.0] - 2026-05-26

- Initial release of the Home Assistant add-on
- Based on BamBuddy v0.2.4.3
- Supports amd64 and aarch64 architectures
- Persistent storage via HA Supervisor data volume
- Configurable bind address for multi-IP setups (e.g. IP alias to avoid port conflicts)
- Configurable timezone and log level

[Unreleased]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.19...HEAD
[1.0.19]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.18...bambuddy-v1.0.19
[1.0.18]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.17...bambuddy-v1.0.18
[1.0.17]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.16...bambuddy-v1.0.17
[1.0.16]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.15...bambuddy-v1.0.16
[1.0.15]: https://github.com/naked-head/homeassistant-addons/compare/bambuddy-v1.0.14...bambuddy-v1.0.15
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
