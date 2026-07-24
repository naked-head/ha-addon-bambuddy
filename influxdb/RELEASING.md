# Releasing InfluxDB

Like Bambu Studio API, this app ships a **pre-built image** (`image:` in
`config.yaml`, published to GHCR by `.github/workflows/influxdb-build.yml`).
The image must exist for every supported architecture before users can
install the new version — otherwise HA offers a version whose image can't be
pulled for that arch, and the Supervisor falls back to building the
Dockerfile locally (slow: it re-downloads and re-installs s6-overlay +
bashio on top of the InfluxDB base image on the user's own hardware).

## Order matters

1. Bump `version:` in `config.yaml`
2. Update `CHANGELOG.md`
3. Merge to `main` — this triggers the builder for **both** amd64 and
   aarch64, **and makes the new version immediately visible and
   installable to everyone tracking this repository** (see note below)
4. **Wait for the builder to finish** and verify both tags exist:
   - `ghcr.io/naked-head/ha-app-influxdb-amd64:<version>`
   - `ghcr.io/naked-head/ha-app-influxdb-aarch64:<version>`
5. Tag the merged commit, for your own reference (see "Tagging" below)

Note the gap between steps 3 and 4: merging publishes the new `version:`
immediately, but the images only appear on GHCR when the builder finishes —
and both architecture jobs must complete, not just the first. A user on the
slower architecture who opens the App Store in that window sees the new
version, fails to pull, and falls back to a local build. To avoid it, run
the builder manually via `workflow_dispatch` with the new version *before*
merging the `version:` bump.

## Before merging

- [ ] CI green (shellcheck, yaml, smoke)
- [ ] `./influxdb/test/smoke.sh` passes locally
- [ ] Fresh install tested (empty `/data`, setup from the Web UI)
- [ ] `init_mode: setup` tested end-to-end (org/bucket/user created, token
      usable)
- [ ] Upgrade tested (existing `/data` from a previous version — no crash,
      no data loss, `init_mode: setup` correctly ignored)
- [ ] `version:` bumped in `config.yaml`
- [ ] `CHANGELOG.md` updated
- [ ] New/changed options documented in `DOCS.md`, `README.md` and
      `translations/`

All of this happens **before** merging, not after — see the note below on
why there's no real staging step once `main` is updated.

## Verify the images were published

    docker pull ghcr.io/naked-head/ha-app-influxdb-amd64:2.8.0-1
    docker pull ghcr.io/naked-head/ha-app-influxdb-aarch64:2.8.0-1

If either pull fails, wait — the builder may still be running for that
architecture (both jobs need to finish, not just the first one to return).

## Tagging (for your own reference only)

The Supervisor's App Store reads `version:` straight from `config.yaml` on
`main` — it doesn't look at git tags or GitHub Releases at all. That means
merging step 3 above **already** ships the new version to every user
tracking this repository, immediately, regardless of anything done here.

Because of that, there's no functional "beta" step for a plain repository
like this one: a `-beta.1` git tag, or a GitHub Release marked as
pre-release, does not hide the version from anyone or gate who can install
it. The community add-on repos that do have a real beta channel (e.g.
`hassio-addons`) achieve it with a **separate repository/branch** that
users opt into independently by adding a second URL in the App Store —
this repo doesn't have that setup, so don't rely on tag naming to provide
that protection.

Given that, the tag is just so you (and anyone reading history) can find
which commit corresponds to which shipped version:

    git tag influxdb-v2.8.0-2
    git push origin influxdb-v2.8.0-2

No GitHub Release needs to be published from it — this matches what's
actually been done for BamBuddy and Bambu Studio API so far (both have
tags, neither has a published Release).

If a change is risky enough that you want a real staged rollout (a bump of
the pinned `influxdb:x.y.z` tag, a `config.yaml` schema change, an
s6-overlay/bashio version bump), the mitigation is to do that verification
**before** merging — thorough local testing per the "Before merging"
checklist above — since merging is the point of no staged return, not
after it.

## Bumping the pinned InfluxDB version

`FROM influxdb:2.8.0` in the Dockerfile pins an external source that can
change under you:

- Always check the [InfluxDB OSS v2 release notes](https://docs.influxdata.com/influxdb/v2/reference/release-notes/influxdb/)
  before bumping — some 2.x releases change on-disk token storage (see the
  2.9.0 token-hashing change) and may not be silently downgrade-safe.
- **Never** bump to a tag outside the 2.x series (`2`, `latest`, `3-core`,
  etc.) — since 27 May 2026 the `latest`/`2` tags on Docker Hub point to
  InfluxDB 3 Core, which is not compatible with an existing v2 database.
- After bumping, re-run the full "Before merging" checklist above,
  including a real upgrade test against `/data` from the previous pinned
  version.

Both of the above are reasons to run the full local verification before
merging, not after — see the note on tagging above for why there's no
staged rollout once `main` is updated.

## If it breaks in production

1. Revert the offending change on `main` (or fix forward), bump `version:`
   in `config.yaml` to a number *higher* than the broken one, and merge.
   Users who already upgraded need a higher version to be offered the fix —
   reverting `version:` to the old number leaves them stuck. Remember the
   builder needs to finish for both architectures before the fix is
   actually installable.
2. Add a scenario to `test/scenarios/` that reproduces the failure.
3. Verify the new scenario fails against the broken image, passes against
   the fix.
