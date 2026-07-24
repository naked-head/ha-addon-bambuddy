# Releasing BamBuddy

## Before tagging

- [ ] CI green on `main` (shellcheck, yaml, smoke)
- [ ] `./test/smoke.sh` passes locally
- [ ] Manual test with `./test/run.sh full` — UI reachable, no errors in log
- [ ] Fresh install tested (empty `/data`, setup from scratch)
- [ ] Upgrade tested (existing `/data` from previous version — no crash, no data loss)
- [ ] `version:` bumped in `config.yaml`
- [ ] `CHANGELOG.md` updated
- [ ] New/changed options documented in `DOCS.md` and `translations/`

All of this happens **before** merging to `main`, not after — see the note
below on why there's no real staging step once `main` is updated.

## Tagging (for your own reference only)

The Supervisor's App Store reads `version:` straight from `config.yaml` on
`main` — it doesn't look at git tags, GitHub Releases, or HACS at all (this
is a Supervisor add-on repository, a different mechanism from HACS, which
only manages integrations/frontend/themes). That means merging your
changes to `main` already ships the new version to everyone tracking this
repository, immediately, regardless of anything done here.

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

    git tag bambuddy-v1.0.13
    git push origin bambuddy-v1.0.13

No GitHub Release needs to be published from it.

If a change is risky enough that you'd want a real staged rollout (a
third-party PR, code ported from another fork, a `config.yaml` schema
change, a refactor of `rootfs/etc/services.d/bambuddy/run`), the
mitigation is to do that verification thoroughly **before** merging — via
the "Before tagging" checklist above — since merging is the point of no
staged return, not after it.

## If it breaks in production

1. Revert the offending change on `main` (or fix forward), bump `version:`
   in `config.yaml` to a number *higher* than the broken one, and merge.
   Users who already upgraded need a higher version to be offered the fix —
   reverting `version:` to the old number leaves them stuck.
2. Add a scenario to `test/scenarios/` that reproduces the failure.
3. Verify the new scenario fails against the broken image, passes against the fix.
