# Releasing Bambu Studio API

Unlike BamBuddy, this App ships a **pre-built image** (`image:` in
`config.yaml`, published to GHCR by `.github/workflows/bambu-studio-api-build.yml`).
The image must exist before users can install the new version — otherwise HA
offers a version whose image cannot be pulled, and the Supervisor falls back to
building the Dockerfile locally (~15 minutes on a typical HA host).

## Order matters

1. Bump `version:` in `config.yaml`
2. Update `CHANGELOG.md`
3. Merge to `main` — this triggers the builder, **and makes the new
   version immediately visible and installable to everyone tracking this
   repository** (see note below)
4. **Wait for the builder to finish** and verify the tag exists at
   `ghcr.io/naked-head/ha-app-bambu-studio-api-amd64:<version>`
5. Tag the merged commit, for your own reference (see "Tagging" below)

Note the gap between steps 3 and 4: merging publishes the new `version:`
immediately, but the image only appears on GHCR when the builder finishes
(~3 minutes). A user who opens the App Store in that window sees the new
version, fails to pull the image, and falls back to a local build. The
window is short, but if you want to avoid it entirely, run the builder
manually via `workflow_dispatch` with the new version *before* merging the
`version:` bump — then the image already exists when the bump lands.

## Before merging

- [ ] CI green (shellcheck, yaml, smoke)
- [ ] `./test/smoke.sh` passes locally
- [ ] `version:` bumped in `config.yaml`
- [ ] `CHANGELOG.md` updated
- [ ] New/changed options documented in `DOCS.md` and `translations/`

All of this happens **before** merging, not after — see the note below on
why there's no real staging step once `main` is updated.

## Verify the image was published

    docker pull ghcr.io/naked-head/ha-app-bambu-studio-api-amd64:0.1.9

If this fails, wait — the builder may still be running.

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

    git tag bambu-studio-api-v0.1.9
    git push origin bambu-studio-api-v0.1.9

No GitHub Release needs to be published from it.

If a change is risky enough that you want a real staged rollout (a
third-party PR, an upstream version bump of `BAMBU_VERSION`/`UPSTREAM_REF`,
or a schema change), the mitigation is to do that verification thoroughly
**before** merging, per the "Before merging" checklist above — since
merging is the point of no staged return, not after it.

## Upstream version bumps

`BAMBU_VERSION` and `UPSTREAM_REF` in the Dockerfile pin external sources that
can change under you:

- A new `BAMBU_VERSION` must have a Linux AppImage on the BambuStudio releases
  page — the build fails fast if not.
- `UPSTREAM_REF` is a branch, not a tag: upstream can move it. A rebuild with
  no local changes can therefore produce a different image.

Both are reasons to run the full local verification before merging, not
after — see the note on tagging above for why there's no staged rollout
once `main` is updated.
