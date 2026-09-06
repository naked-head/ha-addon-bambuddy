#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")" || exit 1

NET=bb-test
IMG=bambuddy:test

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null

cleanup() { docker rm -f bambuddy-smoke sup-mock >/dev/null 2>&1; }
trap cleanup EXIT

FAIL=0
for f in scenarios/*.json; do
  s=$(basename "$f" .json)

  # Web UI port for this scenario. A scenario without a .port sidecar keeps the
  # 8000 default; the value is fed to the mock so the run script reads it back
  # through bashio::addon.port, the way the Supervisor would serve it.
  PORT=8000
  [ -f "scenarios/$s.port" ] && PORT=$(cat "scenarios/$s.port")

  echo "─── $s (port $PORT)"
  cleanup

  if ss -lnt | grep -q ":$PORT "; then
    echo "  ✘ port $PORT in use — close tunnel/container first"
    FAIL=1; continue
  fi

  RUNDIR=$(mktemp -d /tmp/bambuddy-smoke.XXXX)
  mkdir -p "$RUNDIR"/{data,config,share,media}
  cp "$f" "$RUNDIR/data/options.json"
  printf '{"8000/tcp": %s}\n' "$PORT" > "$RUNDIR/network.json"

  docker run -d --name sup-mock --network "$NET" \
    -v "$RUNDIR/data/options.json":/mock/options.json:ro \
    -v "$RUNDIR/network.json":/mock/network.json:ro \
    supervisor-mock >/dev/null

  n=0
  while [ $n -lt 20 ]; do
    docker run --rm --network "$NET" alpine sh -c \
      'wget -qO- http://sup-mock/addons/self/options/config >/dev/null 2>&1' && break
    n=$((n+1)); sleep 0.5
  done

  docker run -d --name bambuddy-smoke --network "$NET" -p "$PORT:$PORT" \
    -v "$RUNDIR/data":/data -v "$RUNDIR/config":/config \
    -v "$RUNDIR/share":/share -v "$RUNDIR/media":/media \
    -e SUPERVISOR_API=http://sup-mock \
    -e SUPERVISOR_TOKEN=fake \
    "$IMG" >/dev/null

  ok=0
  n=0
  while [ $n -lt 30 ]; do
    curl -sf -o /dev/null "http://127.0.0.1:$PORT/" && { ok=1; break; }
    n=$((n+1)); sleep 1
  done

  L=$(docker logs bambuddy-smoke 2>&1 | sed 's/\x1b\[[0-9;]*m//g')

  if [ "$ok" = 1 ]; then
    echo "  ✔ HTTP $PORT up"
  else
    echo "  ✘ HTTP $PORT DOWN"
    tail -30 <<<"$L"
    FAIL=1
  fi

  grep -qiE 'traceback|unbound variable|Failed to get addon config' <<<"$L" && {
    echo "  ✘ errors in log"
    grep -iE 'traceback|unbound variable|Failed to get addon config' <<<"$L" | head -5
    FAIL=1
  }

  # The mock always reports a port, so the fallback warning can only mean that
  # bashio::addon.port came back empty -- the exact silence that let the
  # hardcoded port survive every scenario unnoticed.
  grep -qi 'falling back to 8000' <<<"$L" && {
    echo "  ✘ configured port not read from Supervisor"
    FAIL=1
  }

  grep -q "Starting BamBuddy on port $PORT" <<<"$L" \
    || { echo "  ✘ run script did not start on port $PORT"; FAIL=1; }

  case "$s" in
    full)
      grep -q 'Trusted frame origins: http://ha.test:8123,https://example.com' <<<"$L" \
        || { echo "  ✘ trusted_frame_origins not applied"; FAIL=1; }
      grep -q 'External roots: /share/bambuddy:/share/3dprints:/media/bambuddy' <<<"$L" \
        || { echo "  ✘ external roots not applied"; FAIL=1; }
      grep -q 'Home Assistant URL: http://127.0.0.1:1' <<<"$L" \
        || { echo "  ✘ ha_url not applied"; FAIL=1; }
      grep -q 'Binding to: 0.0.0.0' <<<"$L" \
        || { echo "  ✘ bind_address not applied"; FAIL=1; }
      ;;
    minimal|empty)
      grep -q 'Home Assistant URL: http://supervisor/core' <<<"$L" \
        || { echo "  ✘ ha_url fallback missing"; FAIL=1; }
      ;;
    trust-store-broken)
      grep -q 'no valid certificate' <<<"$L" \
        || { echo "  ✘ certificate warning missing"; FAIL=1; }
      ;;
  esac

  cleanup
  docker run --rm -v "$RUNDIR":/x alpine rm -rf /x/data /x/config /x/share /x/media >/dev/null 2>&1
  rm -f "$RUNDIR/network.json"
  rmdir "$RUNDIR" 2>/dev/null
done

if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "FAILURES"; fi