# BamBuddy – Documentation

This app wraps the official [BamBuddy](https://bambuddy.cool) Docker image as a native Home Assistant Supervisor app, providing local management of Bambu Lab printers without Bambu Cloud.

This app is part of the [`naked-head/homeassistant-addons`](https://github.com/naked-head/homeassistant-addons) collection.

---

## Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `bind_address` | string | *(unset)* | IP address BamBuddy binds to. Leave unset for all IPv4 interfaces (`0.0.0.0`), or set a specific IP alias (e.g. `192.168.50.53`) |
| `log_level` | string | `info` | Log verbosity: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `fatal` |
| `trusted_frame_origins` | list of strings | `[]` | Origins allowed to embed BamBuddy in an iframe — one entry per line, each `scheme://host[:port]`, no paths. Required to use BamBuddy as a HA sidebar webpage panel (e.g. `http://192.168.1.100:8123`) |
| `ha_url` | string | *(unset)* | URL of the Home Assistant instance BamBuddy talks to. Leave unset to use this Supervisor's own Core API automatically |
| `ha_token` | password | *(unset)* | Long-lived access token for `ha_url`. Leave unset to use the Supervisor's own token automatically — only needed if `ha_url` points to a different, external HA instance |
| `database_url` | password | *(unset)* | External PostgreSQL connection string, e.g. `postgresql+asyncpg://bambuddy:password@db-host:5432/bambuddy`. Leave unset to use BamBuddy's built-in SQLite database |
| `share_subfolders` | list | *(empty)* | Subfolders under Home Assistant's `/share` to expose to BamBuddy's File Manager, one per entry (e.g. `bambuddy`). Enter just the subfolder name, without a leading `/share/`. Empty list disables the feature |
| `media_subfolders` | list | *(empty)* | Subfolders under Home Assistant's `/media` to expose to BamBuddy's File Manager, one per entry (e.g. `bambuddy`). Enter just the subfolder name, without a leading `/media/`. Empty list disables the feature |
| `use_system_trust_store` | boolean | `false` | Enable if BamBuddy needs to trust a self-signed certificate (e.g. a self-signed HA instance at `ha_url`) |
| `certfile` | string | `custom_ca.crt` | Filename of the CA certificate to install, placed in this add-on's config folder. Only used when `use_system_trust_store` is enabled |
| `enable_ipv6` | boolean | `false` | Bind on `::` instead of `0.0.0.0` for IPv6 reachability. **Opt-in and off by default** — see warning below |

> **Note on `bind_address` and `trusted_frame_origins`:** these fields have no default value and simply won't appear in the options object until you set them — this is expected, and it avoids a Supervisor quirk where an empty-string default can make an optional field disappear from the UI after a restart.

> **Timezone:** BamBuddy's timezone is detected automatically from Home Assistant at startup via the Supervisor API — there's no `timezone` option to set manually. If the Supervisor can't be reached at startup (e.g. very first boot, temporary network hiccup), BamBuddy falls back to `UTC` until the next restart.

> ⚠️ **`enable_ipv6` warning:** on some systems, binding uvicorn on `::` stops accepting IPv4 connections entirely — even with IPv6 disabled at the OS level (`net.ipv6.bindv6only=0`). This is a uvicorn/asyncio socket behavior we can't detect or guard against from the add-on side. If you enable this and BamBuddy becomes unreachable (locally, via reverse proxy, or via tunnel), disable `enable_ipv6` again from the Configuration tab in YAML mode and restart — this always restores access, since IPv4-only is the default and known-working configuration.

---

## Home Assistant integration (`ha_url` / `ha_token`)

This add-on runs with `homeassistant_api: true`, so on a normal HA Supervised/OS install BamBuddy can already reach the Home Assistant Core API through the Supervisor's internal proxy — **you don't need to set `ha_url` or `ha_token` at all**. They're provided only for the case where you want BamBuddy to talk to a *different* Home Assistant instance than the one running this add-on. The same connection is also used to auto-detect the timezone at startup (see note above).

---

## External library folders (`share_subfolders` / `media_subfolders`)

BamBuddy's File Manager can mount external host folders (NAS shares, USB drives, etc.) without copying files into its own library. This App mounts Home Assistant's `/share` and `/media` folders into the container — the only host paths a HA App is able to expose.

`share_subfolders` and `media_subfolders` scope BamBuddy's access to **named subfolders** of `/share` or `/media`, rather than the whole tree. This matters because `/share` and `/media` are shared by every App and integration on your HA instance — granting BamBuddy the entire folder would let it see (and, if writable, modify) files belonging to unrelated Apps. There is intentionally no option to expose a whole folder.

1. Add one entry per subfolder you want BamBuddy to reach, using just the folder name — **without** a leading `/share/` or `/media/`. For example `bambuddy`, or `3dprints` if you already keep files in `/share/3dprints`.
2. Restart the App. Each folder is created automatically if it doesn't already exist, so you can point BamBuddy at a new folder and populate it afterwards (e.g. via the Samba or File Editor Apps).
3. In BamBuddy, go to **File Manager → Add external folder** and enter the full in-container path, e.g. `/share/bambuddy`.

Entries are sanitised before use: a `..` segment is rejected outright, a redundant `/share/` or `/media/` prefix is stripped with a warning in the log, and a bare `/share` or `/media` is refused. Folders outside `/share` and `/media` cannot be exposed by this App at all.

> **Upgrading from 1.0.15:** `share_subfolder`/`media_subfolder` were single text fields; they are now lists named `share_subfolders`/`media_subfolders`. Re-enter your folder name as a list entry after updating.
>
> **Upgrading from 1.0.14 or earlier:** the `enable_share`/`enable_media` booleans exposed the entire `/share` and/or `/media` folder and no longer exist. Your old setting is not carried over — add a list entry after updating. If your files already lived in a subfolder (e.g. `/share/3dprints`), just enter that name (`3dprints`) and nothing else changes; only files kept directly in the root of `/share` or `/media` need moving into a subfolder first.

---

## External PostgreSQL database (`database_url`)

By default BamBuddy stores everything in a SQLite database under the add-on's persistent data volume. If you'd rather point it at an external PostgreSQL server, set `database_url` (e.g. `postgresql+asyncpg://bambuddy:yourpassword@db-host:5432/bambuddy`). BamBuddy creates all tables automatically on first startup; backup/restore then uses `pg_dump`/`pg_restore` instead of a file copy.

---

## Self-signed certificates (`use_system_trust_store` / `certfile`)

If BamBuddy needs to validate a self-signed certificate — for example when `ha_url` points to a Home Assistant instance reachable only over a self-signed HTTPS certificate — you can install that CA certificate into the add-on's trust store:

1. Place your CA certificate (`.crt` file) in this add-on's config folder (`addon_configs/<slug>_bambuddy/`, accessible via the File Editor add-on).
2. Set `certfile` to the exact filename (default: `custom_ca.crt`).
3. Enable `use_system_trust_store`.
4. Restart the add-on.

If the certificate file isn't found at startup, the add-on logs a warning and leaves the system trust store disabled rather than failing silently.

---

## Ports

| Port | Protocol | Description |
|---|---|---|
| 8000 | TCP | BamBuddy Web UI |
| 3000 | TCP | Slicer bind/detect handshake |
| 3002 | TCP | Slicer bind/detect handshake (alt) |
| 2021 | UDP | SSDP printer discovery |
| 8883 | TCP | MQTT over TLS (Virtual Printer) |
| 6000 | TCP | File transfer tunnel |
| 322 | TCP | RTSP camera streaming (X1/H2/P2) |
| 990 | TCP | FTPS control |
| 2024-2026 | TCP | Proprietary slicer ports (A1/P1S) |
| 50000-50029 | TCP | FTP passive data |

> **Note:** Port 8883 is also used by MQTT brokers. If you already run Mosquitto or another broker on this port, configure a separate IP alias on your network interface and set `bind_address` to that alias.

---

## Add BamBuddy to the Home Assistant sidebar

BamBuddy's web interface cannot be embedded via HA Ingress due to SPA architecture constraints. You can add it as a Webpage dashboard panel instead.

> **How iframe embedding works:** the Webpage panel loads BamBuddy in an iframe directly in the user's browser. This means the browser must be able to reach BamBuddy directly — Home Assistant only acts as a visual container, not as a proxy. This has an important implication: if you access HA via HTTPS from outside your network, the browser will block an HTTP iframe due to mixed content policy.

### Option 1 — Local HTTP access

If you access Home Assistant via HTTP on your local network:

1. Add your HA URL as an entry in `trusted_frame_origins` in the add-on configuration (e.g. `http://192.168.1.100:8123`).
2. Restart the add-on.
3. Go to **Settings → Dashboards**.
4. Click **Add Dashboard** → **Webpage**.
5. Fill in:
   - **Title**: `BamBuddy`
   - **Icon**: `mdi:printer-3d`
   - **URL**: `http://<your-ha-ip>:8000`
6. Click **Create**.

### Option 2 — HTTPS access via Cloudflare Tunnel

If you access Home Assistant via HTTPS and expose BamBuddy through a Cloudflare Tunnel:

#### Step 1 — Create a Cloudflare Transform Rule

1. Go to **Cloudflare Dashboard → your domain → Rules → Overview**.
2. Click **Create rule** and select **Response Header Transform Rule**.
3. Give the rule a name (e.g. `BamBuddy iframe`).
4. Configure the rule:

**When incoming requests match:**
- Field: `Hostname`
- Operator: `equals`
- Value: `bambuddy.yourdomain.com`

**Then modify response header:**
- Operation: `Set`
- Header name: `Content-Security-Policy`
- Value: `frame-ancestors 'self' https://your-ha-domain.com`

Replace `https://your-ha-domain.com` with the URL you use to access Home Assistant.

5. Click **Deploy**.

#### Step 2 — Add BamBuddy to the sidebar

1. Go to **Settings → Dashboards**.
2. Click **Add Dashboard** → **Webpage**.
3. Fill in:
   - **Title**: `BamBuddy`
   - **Icon**: `mdi:printer-3d`
   - **URL**: `https://bambuddy.yourdomain.com`
4. Click **Create**.

### Option 3 — HTTPS access via local Nginx reverse proxy

If you want to serve BamBuddy over HTTPS on your local network without exposing it publicly, you can put Nginx in front of BamBuddy with a self-signed certificate.

#### Step 1 — Install Nginx

Install Nginx on your Home Assistant host or on another machine on the LAN. The [Nginx Proxy Manager](https://nginxproxymanager.com/) add-on for Home Assistant is a convenient option.

#### Step 2 — Configure Nginx

Create a server block that proxies BamBuddy and overrides the CSP header:

```nginx
server {
    listen 443 ssl;
    server_name bambuddy.local;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Override BamBuddy's CSP to allow HA to embed it in an iframe
        proxy_hide_header Content-Security-Policy;
        add_header Content-Security-Policy "frame-ancestors 'self' https://your-ha-domain.com;";
    }
}
```

Replace `your-ha-domain.com` with the URL you use to access Home Assistant.

#### Step 3 — Add BamBuddy to the sidebar

1. Go to **Settings → Dashboards**.
2. Click **Add Dashboard** → **Webpage**.
3. Fill in:
   - **Title**: `BamBuddy`
   - **Icon**: `mdi:printer-3d`
   - **URL**: `https://bambuddy.local`
4. Click **Create**.

> **Note:** If you use a self-signed certificate, your browser may require you to manually accept it by visiting `https://bambuddy.local` once before the iframe loads correctly in HA.

### Option 4 — Remote access via VPN

If you want to access BamBuddy from outside your network without exposing it publicly, use a VPN such as [WireGuard](https://www.wireguard.com/) or [Tailscale](https://tailscale.com/). Both are available as Home Assistant add-ons.

Once connected to the VPN, your remote device is on the LAN and can reach BamBuddy via HTTP as if you were home — use Option 1 in this case.

---

## Virtual Printer setup

### Step 1 — Create a virtual printer in BamBuddy

1. Open BamBuddy at `http://<your-ha-ip>:8000`.
2. Go to **Virtual Printers** and create a new printer.
3. Note the IP, serial number and access code assigned to the virtual printer.

### Step 2 — Download the CA certificate

1. In BamBuddy go to **Settings → Virtual Printer**.
2. Download the **CA Certificate** (`bbl_ca.crt`).

### Step 3 — Add the certificate to BambuStudio

Append the contents of `bbl_ca.crt` to the slicer certificate file.

**Standard installation:**
```
<BambuStudio install path>/resources/cert/printer.cer
```

**Flatpak installation:**
```
/var/lib/flatpak/app/com.bambulab.BambuStudio/current/active/files/share/BambuStudio/resources/cert/printer.cer
```
or
```
/var/lib/flatpak/app/com.bambulab.BambuStudio/current/active/files/share/BambuStudio/cert/printer.cer
```

> **Note:** Updating BambuStudio via Flatpak overwrites `printer.cer` — you will need to re-add the certificate after each update.

### Step 4 — Add the virtual printer in BambuStudio

1. In BambuStudio go to **Device → Add Printer**.
2. Select **Add a new Bambu Lab printer**.
3. Enter the IP, serial number and access code from Step 1.

---

## Data persistence

BamBuddy data (database, virtual printer certificates, logs) is stored in the HA Supervisor data volume and survives add-on updates and restarts.

### BamBuddy backups (`/share/bambuddy_backups`)

If you use BamBuddy's own backup feature, the resulting files are stored under `/share/bambuddy_backups` rather than inside the add-on's persistent data volume. This is deliberate: Home Assistant's own App/Supervisor backups snapshot the entire persistent data volume, so a BamBuddy backup stored *inside* that volume would get bundled into every subsequent HA backup — including all previous BamBuddy backups still sitting there — growing the HA backup file without bound.

`/share` is never included in HA's own backups by default, so this keeps the two backup systems independent: back up BamBuddy from within BamBuddy, and back up Home Assistant (config, other Apps) with HA's own backup feature, without either one duplicating the other's data.

If you were running a version before 1.0.15, any backups already present in the old location are **moved** here the first time you start 1.0.15 — copied first, verified file by file, and only then removed from the data volume. Leaving a second copy behind would keep inflating your HA backups, which is exactly what this change avoids, so nothing is left over and there's nothing for you to clean up.

If the migration can't be verified (a failed copy, a full disk, a read-only `/share`), nothing is deleted: the originals stay put under `backups.not-migrated` and the App log shows an error. That folder is *not* removed automatically and will keep bloating your HA backups until you deal with it — see the 1.0.15 entry in [CHANGELOG.md](CHANGELOG.md) for step-by-step cleanup instructions.

---

## Support

For issues with the **add-on packaging**:
<https://github.com/naked-head/homeassistant-addons/issues>

For issues with **BamBuddy itself**:
- [BamBuddy wiki](https://wiki.bambuddy.cool)
- [BamBuddy GitHub](https://github.com/maziggy/bambuddy/issues)
