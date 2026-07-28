# BamBuddy – Home Assistant App

<p align="center">
  <img src="https://bambuddy.cool/assets/img/logo_transparent.png" alt="BamBuddy" width="300">
</p>

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]
[![License][license-shield]](LICENSE)

A Home Assistant app that runs [BamBuddy](https://bambuddy.cool) — a self-hosted command center for Bambu Lab printers. Manage your entire printer farm locally, without Bambu Cloud.

This app is part of the [`naked-head/homeassistant-addons`](https://github.com/naked-head/homeassistant-addons) collection.

---

## Requirements

- Home Assistant OS or Supervised installation (Supervisor required)
- amd64 or aarch64 architecture

---

## Installation

### Via button (recommended)

[![Add Repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https://github.com/naked-head/homeassistant-addons)

### Manual

1. In Home Assistant, go to **Settings → Apps → App Store**.
2. Click the three-dot menu → **Repositories**.
3. Add `https://github.com/naked-head/homeassistant-addons`.
4. Find **BamBuddy** in the store and click **Install**.

---

## Configuration

| Option | Default | Description |
|---|---|---|
| `bind_address` | *(unset)* | IP to bind to. Leave unset for all IPv4 interfaces, or set a specific IP alias (e.g. `192.168.50.53`) |
| `log_level` | `info` | Log verbosity: `trace`, `debug`, `info`, `warning`, `error` |
| `trusted_frame_origins` | `[]` | Origins allowed to embed BamBuddy in an iframe — one entry per line, `scheme://host[:port]`, e.g. `http://192.168.1.100:8123` |
| `ha_url` / `ha_token` | *(unset)* | Point BamBuddy at a Home Assistant instance. Leave unset to auto-use this Supervisor's own Core API (also used to auto-detect the timezone) |
| `database_url` | *(unset)* | External PostgreSQL connection string. Leave unset to use the built-in SQLite database |
| `share_subfolder` / `media_subfolder` | *(unset)* | Expose a specific subfolder of HA's `/share` and/or `/media` (e.g. `bambuddy`) as a File Manager external folder — not the whole folder |
| `use_system_trust_store` / `certfile` | `false` / `custom_ca.crt` | Trust a self-signed certificate placed in the add-on's config folder |
| `enable_ipv6` | `false` | Bind on `::` for IPv6 reachability. Opt-in — can make BamBuddy unreachable on some systems, see [DOCS.md](DOCS.md) |

See the [full documentation](DOCS.md) for details on each option.

> **Note on port 8883:** this port is also used by MQTT brokers. If you already run Mosquitto on the same machine, configure a separate IP alias and set `bind_address` accordingly. See the [full documentation](DOCS.md) for details.

---

## Add BamBuddy to the Home Assistant sidebar

BamBuddy cannot be embedded via HA Ingress due to SPA architecture constraints. You can add it as a Webpage dashboard panel instead — see the [full documentation](DOCS.md#add-bambuddy-to-the-home-assistant-sidebar) for setup instructions, including the Cloudflare configuration for HTTPS users.

---

## Support

- [Full documentation](DOCS.md)
- [BamBuddy wiki](https://wiki.bambuddy.cool)
- [BamBuddy GitHub](https://github.com/maziggy/bambuddy)
- [Add-on issues](https://github.com/naked-head/homeassistant-addons/issues)

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
[license-shield]: https://img.shields.io/badge/license-MIT-green.svg