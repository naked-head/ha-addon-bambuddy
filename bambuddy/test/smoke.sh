#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")" || exit 1

NET=bb-test
IMG=bambuddy:test

if ss -lnt | grep -q ':8000 '; then
  echo "✘ port 8000 in use — close tunnel/container first"; exit 1
fi

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null

cleanup() { docker rm -f bambuddy-smoke sup-mock >/dev/null 2>&1; }
trap cleanup EXIT

FAIL=0
for f in scenarios/*.json; do
  s=$(basename "$f" .json)
  echo "─── $s"
  cleanup

  RUNDIR=$(mktemp -d /tmp/bambuddy-smoke.XXXX)
  mkdir -p "$RUNDIR"/{data,config,share,media}
  cp "$f" "$RUNDIR/data/options.json"

  docker run -d --name sup-mock --network "$NET" \
    -v "$RUNDIR/data/options.json":/mock/options.json:ro \
    supervisor-mock >/dev/null

  n=0
  while [ $n -lt 20 ]; do
    docker run --rm --network "$NET" alpine sh -c \
      'wget -qO- http://sup-mock/addons/self/options/config >/dev/null 2>&1' && break
    n=$((n+1)); sleep 0.5
  done

  docker run -d --name bambuddy-smoke --network "$NET" -p 8000:8000 \
    -v "$RUNDIR/data":/data -v "$RUNDIR/config":/config \
    -v "$RUNDIR/share":/share -v "$RUNDIR/media":/media \
    -e SUPERVISOR_API=http://sup-mock \
    -e SUPERVISOR_TOKEN=fake \
    "$IMG" >/dev/null

  ok=0
  n=0
  while [ $n -lt 30 ]; do
    curl -sf -o /dev/null http://127.0.0.1:8000/ && { ok=1; break; }
    n=$((n+1)); sleep 1
  done

  L=$(docker logs bambuddy-smoke 2>&1 | sed 's/\x1b\[[0-9;]*m//g')

  if [ "$ok" = 1 ]; then
    echo "  ✔ HTTP 8000 up"
  else
    echo "  ✘ HTTP 8000 DOWN"
    tail -30 <<<"$L"
    FAIL=1
  fi

  grep -qiE 'traceback|unbound variable|Failed to get addon config' <<<"$L" && {
    echo "  ✘ errors in log"
    grep -iE 'traceback|unbound variable|Failed to get addon config' <<<"$L" | head -5
    FAIL=1
  }

  case "$s" in
    full)
      grep -q 'Trusted frame origins: http://ha.test:8123,https://example.com' <<<"$L" \
        || { echo "  ✘ trusted_frame_origins not applied"; FAIL=1; }
      grep -q 'External roots: /share/bambuddy:/media/bambuddy' <<<"$L" \
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
  rmdir "$RUNDIR" 2>/dev/null
done

if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "FAILURES"; fi
exit $FAIL