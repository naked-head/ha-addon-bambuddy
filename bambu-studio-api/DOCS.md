# Bambu Studio API – Documentation

This App runs the `bambu-studio-api` sidecar described in the
[Bambuddy slicer-api documentation](https://wiki.bambuddy.cool/features/slicer-api/).
It exposes a REST API that Bambuddy (or any compatible client) can call to slice STL / STEP / 3MF files server-side, without a desktop slicer install.

This App is part of the [naked-head/homeassistant-addons](https://github.com/naked-head/homeassistant-addons)
collection, forked from [griffinmartin/ha-app-bambu-studio-api](https://github.com/griffinmartin/ha-app-bambu-studio-api).

---

## Architecture

- **amd64 only.** Bambu Lab does not publish an official ARM64 AppImage, so this App cannot be installed on aarch64 Home Assistant hosts. On those hosts run the sidecar on a separate x86_64 machine and point Bambuddy at it over your LAN. See the
  [platform requirements section of the Bambuddy wiki](https://wiki.bambuddy.cool/features/slicer-api/#platform-requirements).

---

## Configuration Options

### Debug

| Option  | Type | Default |
|---------|------|---------|
| `debug` | bool | `false` |

Enables verbose Express debug logs from the Node wrapper (`DEBUG=express:*`). Leave this off in normal operation — turn it on only while diagnosing a slice failure.

---

## Network

The host port for the API is editable under **Configuration → Network**, *not* under **Configuration → Options**:

| Container port | Default host port | Purpose |
|----------------|-------------------|---------|
| `3000/tcp`     | `3001`            | REST API + `/health` |

`3001` matches the Bambuddy wiki's default for `bambu-studio-api`. Change the host port only if 3001 collides with something else on your Home Assistant host. Bambuddy's virtual-printer feature already reserves host ports 3000 and 3002, so **don't move this App to either of those**.

---

## Pointing Bambuddy at this App

1. Make sure this App is **started** and the **Log** tab shows the wrapper listening on port 3000.
2. In Bambuddy: **Settings → Workflow → Slicer**.
3. Set **Preferred Slicer** to **Bambu Studio**.
4. Toggle **Use Slicer API** on.
5. Set **Sidecar URL** to `http://<your-ha-ip>:3001` (replace the port if you changed it under Network).

Verify with:

```
curl http://<your-ha-ip>:3001/health
```

The response should be a JSON document. A cosmetic quirk of the upstream wrapper: `/health` may report `version: "unknown"` and `checks: orcaslicer` even on this Bambu Studio variant — those are [known cosmetic issues](https://wiki.bambuddy.cool/features/slicer-api/#health-reports-version-unknown) and don't mean the wrong binary is loaded.

---

## Data Persistence

The wrapper's data directory (uploaded presets, imported `.bbscfg` bundles, profile cache, etc.) is bind-mounted to:

```
addon_configs/<slug>_bambu_studio_api/data/
```

which is accessible via the **File Editor** App. Data survives restarts, App updates, and reinstalls (as long as you opt to keep App data when uninstalling).

The wrapper expects the profile layout below — it's created automatically on first slice, but you can pre-populate it by dropping JSON exports in:

```
data/
├── printers/
├── presets/
└── filaments/
```

---

## Bambu Studio Version

The Bambu Studio AppImage version is pinned at **image build time** via the `BAMBU_VERSION` build-arg in the App's Dockerfile.
Bambu Studio version updates are handled **automatically**: a daily GitHub Actions workflow checks for new [BambuStudio releases](https://github.com/bambulab/BambuStudio/releases) and opens a Pull Request against [naked-head/homeassistant-addons](https://github.com/naked-head/homeassistant-addons) when a newer version is available. Once the PR is merged, a new App image is built and published automatically, and Home Assistant will offer the update through the normal App update mechanism.
To upgrade Bambu Studio you have to update the App itself (a new release that bumps the build-arg and the App `version`).

---

## Troubleshooting

### The App takes 5–10 minutes to install

Expected on first install. The App's Dockerfile downloads the Bambu Studio AppImage (~220 MB) and builds the Node wrapper from source. Subsequent restarts and App updates reuse the cached image.

### `/health` is reachable but slice jobs hang in Bambuddy

Re-check:

- That **Sidecar URL** in Bambuddy matches the host port you see in **Configuration → Network**.
- That Bambuddy and this App can reach each other (use the HA host's LAN IP, not `localhost`, if Bambuddy runs in its own container on a different Docker network).

See the [Bambuddy wiki's troubleshooting section](https://wiki.bambuddy.cool/features/slicer-api/#troubleshooting) for slice-specific debugging steps.

### `Failed to slice the model`

The wrapper hides the underlying CLI stderr by default. To see it, open a shell into the running container and re-run the slice manually as documented [upstream](https://wiki.bambuddy.cool/features/slicer-api/#failed-to-slice-the-model).
In HA you can use the **SSH & Web Terminal** App plus `docker exec -it addon_<slug>_bambu_studio_api bash`.

---

## Third-party software

This App packages software published by others, under their own licenses:

- The **wrapper**, [maziggy/orca-slicer-api](https://github.com/maziggy/orca-slicer-api)
  (branch `bambuddy/profile-resolver`), is licensed under the **AGPL-3.0**. The
  AGPL grants you the right to obtain the source of software you interact with
  over a network — which is what this App serves. The complete source is
  available at the link above.
- The **Bambu Studio CLI** is published by Bambu Lab under its own terms; the
  AppImage is downloaded at image build time from the
  [BambuStudio releases](https://github.com/bambulab/BambuStudio/releases).

The packaging in this repository — Dockerfile, service scripts, configuration
and this documentation — is MIT licensed and lives at
[naked-head/homeassistant-addons](https://github.com/naked-head/homeassistant-addons).

---

## Support

For issues with the **App packaging itself**:
<https://github.com/naked-head/homeassistant-addons/issues>

For issues with the **wrapper** or the **Bambu Studio CLI**, file upstream:

- Wrapper: <https://github.com/maziggy/orca-slicer-api/issues>
- Bambu Studio: <https://github.com/bambulab/BambuStudio/issues>
- Bambuddy: <https://github.com/maziggy/bambuddy/issues>