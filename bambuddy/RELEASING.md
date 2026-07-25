# Releasing BamBuddy

This add-on ships a **pre-built image** (`image:` in `config.yaml`, published
to GHCR by `.github/workflows/bambuddy-build.yml`). The image must exist for
every supported architecture **before** users are offered the new version —
otherwise HA offers a version whose image can't be pulled for that arch, and
the Supervisor falls back to building the Dockerfile locally on the user's own
hardware (slow, and on low-RAM ARM boards like a Pi 4 it can exhaust memory
and hang the whole system — this is exactly the failure mode pre-built images
were introduced to fix).

## Before merging

- [ ] CI green on the feature branch (shellcheck, yaml, smoke)
- [ ] `./test/smoke.sh` passes locally
- [ ] Manual test with `./test/run.sh full` — UI reachable, no errors in log
- [ ] Fresh install tested (empty `/data`, setup from scratch)
- [ ] Upgrade tested (existing `/data` from previous version — no crash, no data loss)
- [ ] `version:` bumped in `config.yaml`
- [ ] `CHANGELOG.md` updated
- [ ] New/changed options documented in `DOCS.md` and `translations/`

## Release order (important)

Because the Supervisor reads `version:` straight from `config.yaml` on `main`,
merging ships the new version to everyone tracking this repository immediately.
With a pre-built image, the image for that version **must already be on GHCR**
when that happens. The safe order is:

1. Bump `version:` in `config.yaml` and update `CHANGELOG.md` on your feature branch.
2. Before merging, trigger the builder manually against your branch via
   **Actions → BamBuddy Builder → Run workflow**, passing the new version in
   the `version` input. This publishes the image ahead of the merge.
3. Verify both images exist on GHCR:
   - `ghcr.io/naked-head/ha-app-bambuddy-amd64:<version>`
   - `ghcr.io/naked-head/ha-app-bambuddy-aarch64:<version>`
4. Merge the PR to `main`. The builder runs again on push (idempotent — it
   re-tags the same content), and users are now offered a version whose image
   is already pullable.

If you skip step 2, there's a window (~3-5 min for the aarch64 QEMU build)
between merge and image availability where a user hitting "Update" gets a
failed pull or a local build fallback.

## GHCR package visibility

The first time the builder publishes each image, the GHCR package is created
**private** by default. HA cannot pull a private image. After the first build,
go to GitHub → your profile → **Packages** → `ha-app-bambuddy-amd64` and
`ha-app-bambuddy-aarch64` → **Package settings → Change visibility → Public**.
This is a one-time step per package.

## Tagging (for your own reference only)

The tag just lets you (and anyone reading history) find which commit
corresponds to which shipped version:

    git tag bambuddy-v1.0.14
    git push origin bambuddy-v1.0.14

No GitHub Release needs to be published from it.

## If it breaks in production

1. Revert the offending change on `main` (or fix forward), bump `version:`
   in `config.yaml` to a number *higher* than the broken one, and merge.
   Users who already upgraded need a higher version to be offered the fix —
   reverting `version:` to the old number leaves them stuck.
2. Wait for the builder to publish the fixed image before announcing the fix.
3. Add a scenario to `test/scenarios/` that reproduces the failure.
4. Verify the new scenario fails against the broken image, passes against the fix.