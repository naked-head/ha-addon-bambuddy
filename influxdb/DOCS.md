# InfluxDB – Documentation

This App runs **InfluxDB OSS 2.8.0** (2.x series) as a native Home Assistant
Supervisor App. It fills the gap left by `hassio-addons/addon-influxdb`,
which only covers InfluxDB v1.x and is no longer maintained.

This App is part of the [`naked-head/homeassistant-addons`](https://github.com/naked-head/homeassistant-addons) collection.

---

## What's included

- InfluxDB OSS **2.8.0** (official InfluxData image, multi-arch amd64/arm64)
- Data persisted under `/data` (Supervisor-managed: HA snapshots/backups
  include it automatically)
- Port **8086** exposed (HTTP API + Web UI)
- Initial setup (org, bucket, user, token) either from the Web UI **or**
  via configurable environment variables
- Support for `influx backup` / `influx restore` from inside the container

---

## Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `reporting` | bool | `false` | Send anonymous usage data to InfluxData. Disabled by default for privacy. |
| `log_level` | list | `info` | `trace`, `debug`, `info`, `warn`, `error`, `fatal`. |
| `init_mode` | list | `skip` | `skip`: no automatic setup, do it yourself from the Web UI on first boot (or restore a backup). `setup`: initial setup runs automatically using the values below. |
| `init_username` | str | — | Initial admin username. Required if `init_mode: setup`. |
| `init_password` | password | — | Password for the initial user. Required if `init_mode: setup`. |
| `init_org` | str | — | Initial organization. Required if `init_mode: setup`. |
| `init_bucket` | str | — | Initial bucket. Required if `init_mode: setup`. |
| `init_admin_token` | password | — | Operator token to set explicitly (optional: if empty, InfluxDB generates a random one, readable afterwards from the Web UI under *Load Data → API Tokens*). |
| `init_retention` | str | `"0"` | Retention for the initial bucket, in seconds. `"0"` = infinite. |

**Important:** automatic setup via `init_mode: setup` only runs on the
**very first boot**, while `/data` is still empty. On every later restart
these options are ignored — there's no risk of recreating the org/bucket or
overwriting existing data. If you already have data (e.g. from a
migration, see below), leave `init_mode: skip`.

---

## Initial setup from the Web UI (recommended for a fresh install)

1. Leave `init_mode: skip`.
2. Start the App.
3. Go to `http://<your-server-address>:8086`.
4. Follow the wizard: create user, org, bucket, password. InfluxDB
   generates the operator token itself, visible afterwards under
   *Load Data → API Tokens*.

## Automatic setup via options

Useful for reproducible installs (e.g. IaC, repo references):

```yaml
init_mode: setup
init_username: admin
init_password: "a-strong-password"
init_org: home
init_bucket: home_assistant
init_retention: "0"
```

Leave `init_admin_token` empty to let InfluxDB generate it, or set it if
you want a known token upfront (e.g. to reuse immediately in Home
Assistant Core's `influxdb:` integration).

---

## Migrating from a Docker container on another host (e.g. a Raspberry Pi 4)

Two valid approaches, both safe since source and destination are both
InfluxDB **2.8.0** — no schema-compatibility concerns:

### Option A — backup/restore (recommended, safer)

On the old host, with the old container still running:

```bash
docker exec <old-container-name> influx backup /tmp/influx-backup \
  --token <operator-token>
docker cp <old-container-name>:/tmp/influx-backup ./influx-backup
```

Copy the `influx-backup` folder to the new server, then, with the new App
**started once** (to create `/data`) and then **stopped**:

```bash
docker cp ./influx-backup <app-container-name>:/tmp/influx-backup
docker exec <app-container-name> influx restore /tmp/influx-backup \
  --token <operator-token>
```

Find the App's container name with `docker ps | grep influxdb` (typically
`addon_<repo>_influxdb` once installed from the repository, or
`addon_local_influxdb` if you're developing/testing it locally).

### Option B — direct file copy (faster, same version)

Since source and destination are both **2.8.0**, you can also stop the old
container and copy three items straight from its data volume
(`/var/lib/influxdb2` by default) into `/data` on the new App:

- `influxd.bolt` (users, orgs, buckets, dashboards, tasks)
- `influxd.sqlite` (notebooks and annotations — easy to miss, since it's a
  separate file from the bolt DB; skipping it silently loses notebooks and
  annotations, not the actual time-series data)
- the `engine/` folder (the actual time-series data)

Expected final paths: `/data/influxd.bolt`, `/data/influxd.sqlite`, and
`/data/engine/`. Then start the new App with `init_mode: skip`. Faster on
large datasets, but without the validation `influx restore` performs on
the data.

Either way, keep the old container stopped (or at least not writing to the
same bucket) until you've confirmed the new App works correctly, to avoid
two sources writing to the same history in parallel.

---

## Backup and restore from inside the container

Find the container name with `docker ps | grep influxdb`.

```bash
# Full backup (all orgs/buckets)
docker exec <container-name> influx backup /data/manual-backup \
  --token <operator-token>

# Backup a single bucket
docker exec <container-name> influx backup /data/manual-backup \
  --bucket home_assistant --token <operator-token>

# Restore
docker exec <container-name> influx restore /data/manual-backup \
  --token <operator-token>
```

Note: writing the backup inside `/data` also gets picked up by Home
Assistant's automatic snapshots. If you'd rather keep it out of automatic
snapshots, write it elsewhere in the container and `docker cp` it out
before deleting it.

---

## Home Assistant Core integration

Once org/bucket/token exist, in `configuration.yaml`:

```yaml
influxdb:
  api_version: 2
  host: <your-server-address>
  port: 8086
  token: <api-token>
  organization: <org>
  bucket: <bucket>
  max_retries: 3
  default_measurement: units
```

---

## A note on the image tag

This App pins `influxdb:2.8.0` explicitly in the Dockerfile. **Never use
the `latest` or `2` tag**: since 27 May 2026 those tags point to InfluxDB 3
Core, which is not compatible with an existing v2 database. Version
upgrades for this App are therefore always explicit, never automatic via a
moving tag.

---

## Web UI access (no Ingress)

This App does **not** use Home Assistant's Ingress. That's not an
arbitrary choice: the old community App `hassio-addons/addon-influxdb`
(v1, no longer maintained) managed Ingress because it actually put
**Chronograf** — the separate web dashboard InfluxData shipped for the 1.x
series — behind an **nginx + Lua module** that rewrote requests to work
under the subpath the Supervisor assigns.

InfluxDB **v2** dropped Chronograf: the Web UI is a React SPA baked
directly into `influxd`, and it has never had an option to serve
assets/API from a subpath. It's an open upstream issue since 2020/2021,
never resolved — assets (`<script src="/xxxxx.js">`) are always requested
at the root path, so any reverse proxy on a subpath (including the
Supervisor's Ingress) breaks the UI. There's no way around it short of
rewriting every HTML/JS response on the fly, which would be fragile and
break on every InfluxDB update.

Instead, `config.yaml` defines:

- `webui: "http://[HOST]:[PORT:8086]"` — an **Open Web UI** button on the
  App's Info tab, opening `http://<host>:8086` in a new tab.
- `watchdog: "http://[HOST]:[PORT:8086]/health"` — the Supervisor restarts
  the App if the health check stops responding.

### Alternative: Webpage panel in the sidebar

If you still want quick access from Home Assistant's sidebar (without
going through Ingress, so without the subpath problem), you can add
InfluxDB as a **Webpage** panel. Unlike Ingress, this is a plain iframe
pointed directly at host:port, so InfluxDB behaves as if opened in a
normal browser tab.

In `configuration.yaml`:

```yaml
panel_iframe:
  influxdb:
    title: "InfluxDB"
    icon: mdi:chart-areaspline
    url: "http://<your-server-address>:8086"
    require_admin: true
```

Or, if you'd rather do it from a dashboard instead of a fixed sidebar
panel, add a **Webpage** card (`type: iframe`) pointed at the same URL.

Note: since this is a direct iframe (not Ingress), the browser needs to
reach `<your-server-address>:8086` directly — same LAN, or behind your own
reverse proxy/tunnel if accessing from outside. If you serve Home
Assistant over HTTPS while InfluxDB stays on plain HTTP, some browsers
block the mixed content — same fix as already in use for other Apps
(Cloudflare Transform Rules for the CSP header, or exposing InfluxDB over
HTTPS too).

---

## Internal structure

This App follows the same pattern used in `bambu-studio-api` for non-HA
bases: it starts from the official InfluxData image (`influxdb:2.8.0`),
installs **s6-overlay v3** and **bashio** on top by hand, and uses the
service script `rootfs/etc/services.d/influxdb/run` (shebang
`#!/usr/bin/with-contenv bashio`) instead of a custom entrypoint. The
Dockerfile's `ENTRYPOINT` is `["/init"]` (s6), and the `run` script
ultimately hands off to the official InfluxData entrypoint
(`/entrypoint.sh influxd`), which handles setup and starts `influxd`.

---

## Third-party software

This App packages [InfluxDB OSS](https://github.com/influxdata/influxdb),
published by InfluxData under the **MIT** license. The packaging in this
repository — Dockerfile, service scripts, configuration and this documentation
— is MIT licensed too and lives at
[naked-head/homeassistant-addons](https://github.com/naked-head/homeassistant-addons).

---

## Known limitations

- No Ingress support (see above): the App exposes port 8086 directly, with
  `webui`/`watchdog` in `config.yaml` and, optionally, a Webpage panel for
  sidebar access.
- `init_mode: setup` does nothing if `/data` already contains a database
  (upstream behavior, not specific to this App).