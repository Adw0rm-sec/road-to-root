# Chapter 05 — "Capabilities" · Debrief

> Full walkthrough for `hollow-vault-01` (`target-caps`). Five file-capability
> paths from `labuser1` to root. Try the box with [README.md](README.md) first.

**Flag:** `/root/flag.txt` → `R2R{c4p4b1l1t1es_are_suid_without_the_b1t}`

---

## The one idea

Root is not one thing. Since Linux 2.2 the kernel splits root's authority into
distinct **capabilities** (see `capabilities(7)`): `CAP_SETUID`,
`CAP_DAC_OVERRIDE`, `CAP_DAC_READ_SEARCH`, `CAP_NET_BIND_SERVICE`, and ~37 more.
A capability can be attached to an executable file with `setcap`, so the
program runs with that one slice of power — **without** the SUID bit, and
without being owned by root in the SUID sense.

That's good security engineering (least privilege) and a great foothold when
someone grants one capability too many, or pins it to a program that lets the
caller choose what it does.

The three file-capability sets:

| Set | Letter | Meaning |
|---|---|---|
| Permitted | `p` | the caps the process is *allowed* to raise into effective |
| Effective | `e` | the caps that are *active right now* (checked on syscalls) |
| Inheritable | `i` | passed across `execve` (rarely used; ambient caps replaced it) |

`setcap cap_setuid+ep file` = permitted **and** effective, so the capability is
live the instant the binary runs. That `+ep` is what makes these binaries
dangerous straight out of the box.

**Recon that finds all five:**

```bash
getcap -r / 2>/dev/null
/usr/local/bin/captar cap_dac_read_search=ep
/usr/local/bin/plvault cap_setuid=ep
/usr/local/bin/pyvault cap_setuid=ep
/usr/local/bin/svc-runner cap_setuid=ep
/usr/local/bin/vault-write cap_dac_override=ep
```

---

## Station A — `cap_setuid` on python3  ·  ★★☆☆

### 1. Recon
`getcap -r /` shows `/usr/local/bin/pyvault cap_setuid=ep`. It's a copy of the
Python interpreter: `file /usr/local/bin/pyvault` → ELF, and `pyvault --version`
prints a Python version. An interpreter with `cap_setuid` is game over.

### 2. The flaw
`CAP_SETUID` lets a process call `setuid(2)` to any uid, including 0, with no
check. An interpreter runs code you write — so you can make it call `setuid(0)`
and then launch a shell. The binary is root-owned but not SUID; the capability
is the whole power.

### 3. Exploit
```bash
pyvault -c 'import os; os.setuid(0); os.system("/bin/bash")'
id            # uid=0(root)
cat /root/flag.txt
```

### 4. Why it works
`cap_setuid+ep` means `CAP_SETUID` is in the effective set the moment `pyvault`
execs. `os.setuid(0)` would normally fail for a non-root process (`EPERM`);
with the capability it succeeds, and every subsequent process (`/bin/bash`)
inherits uid 0. Note `id` still shows `gid=1001` — `CAP_SETUID` changes the
uid, not the gid; a root uid is enough to read the flag and own the box.

### 5. Detect
```bash
getcap -r / 2>/dev/null | grep -i setuid
```
Any interpreter, shell, or language runtime with `cap_setuid` / `cap_setgid`
is a critical finding. Watch the GTFOBins "Capabilities" list.

### 6. Harden
`setcap -r /usr/local/bin/pyvault`. Never put `cap_setuid` on an interpreter.
If a service legitimately needs to drop privileges, give the capability to a
tiny purpose-built helper that does exactly one thing and hands control to
nothing attacker-controlled — not to python/perl/ruby.

### 7. Real world
This is GTFOBins' canonical "Capabilities" entry for `python`, `perl`, `ruby`,
`node`, `php`, and others. It bites whenever a container or deploy script does
`setcap cap_setuid+ep $(which python3)` to let an app bind-or-drop without
running the whole service as root.

---

## Station B — `cap_setuid` on perl  ·  ★★☆☆

### 1. Recon
`getcap -r /` → `/usr/local/bin/plvault cap_setuid=ep`. Same class as A, a
different runtime.

### 2. The flaw
Identical to A: a scripting runtime carrying `CAP_SETUID`.

### 3. Exploit
```bash
plvault -e 'use POSIX qw(setuid); setuid(0); exec "/bin/bash";'
id ; cat /root/flag.txt
```

### 4. Why it works
`POSIX::setuid(0)` is a thin wrapper over the `setuid(2)` syscall; the file
capability makes it succeed. `exec` replaces the Perl process with a root
shell. Two different interpreters, one lesson: the language doesn't matter, the
capability does.

### 5. Detect / 6. Harden
Same as A — `getcap -r /` and remove the capability. The point of shipping both
A and B is that your recon has to enumerate *every* capped binary, not stop at
the first interpreter.

### 7. Real world
Perl shows up with `cap_setuid` in legacy monitoring and backup agents that
needed to switch users. GTFOBins "perl → Capabilities".

---

## Station C — `cap_dac_read_search` on tar  ·  ★★★☆

### 1. Recon
`getcap -r /` → `/usr/local/bin/captar cap_dac_read_search=ep`. A copy of
`tar`. This one is special: it does **not** give you a root shell. It gives you
*read*.

### 2. The flaw
`CAP_DAC_READ_SEARCH` bypasses all filesystem **read** and directory **search**
permission checks. A process holding it can read any file and traverse any
directory, regardless of mode. `tar` reads files to archive them — so capped
`tar` can archive files you have no permission to read.

### 3. Exploit
```bash
cd /tmp && mkdir loot && cd loot
captar -cf flag.tar -C / root/flag.txt    # archive a file you can't read
captar -xf flag.tar                       # extract into a dir you own
cat root/flag.txt                          # R2R{...}  — read as labuser1
```
You never became root. You read a `600 root:root` file as `labuser1`.

### 4. Why it works
`captar` opens `/root/flag.txt` for reading; the kernel would normally return
`EACCES`, but `CAP_DAC_READ_SEARCH` waives the check. The bytes go into the
archive. Extraction, done as `labuser1`, writes a copy **owned by you**, so you
can read it with a plain `cat`. Confidentiality is broken without any uid
change — a reminder that "root" and "can read root's files" are different wins,
and plenty of flags/secrets only need the second.

### 5. Detect
```bash
getcap -r / 2>/dev/null | grep -iE 'dac_read_search|dac_override'
```
Also note this is the one capability the lab had to **add** to the container.
Audit your container runtime's cap set (`capsh --print`, the compose
`cap_add`): a binary's file capability only fires if the capability is also in
the process **bounding set**. Granting `DAC_READ_SEARCH` container-wide is a
smell on its own.

### 6. Harden
Remove the capability; if archiving root-owned data is a real need, run that job
as a dedicated account with group read, not with a DAC-bypass capability. Keep
the container bounding set minimal — don't `cap_add` things the app doesn't
truly need.

### 7. Real world
GTFOBins lists `cap_dac_read_search` for `tar`, `cp`, `rsync`, and more. It's a
favourite on CTF boxes precisely because it's a *silent* read primitive — no
root prompt, no shell, just the file.

> **Why the extra `cap_add`?** Docker's default bounding set includes
> `CAP_SETUID` and `CAP_DAC_OVERRIDE` but **not** `CAP_DAC_READ_SEARCH`. A file
> capability can only become effective if the capability is also in the
> process's bounding set, so on a stock container `captar` fails to exec with
> `Operation not permitted` until the admin adds the cap. Stations A, B, D and E
> need no such grant. This is a genuine real-world nuance: file caps and
> container caps have to line up.

---

## Station D — `cap_dac_override` on a config writer  ·  ★★★☆

### 1. Recon
`getcap -r /` → `/usr/local/bin/vault-write cap_dac_override=ep`. `vault-write
<path>` appends stdin to a file. Try it on a file you own to see the behaviour,
then aim it at root's.

### 2. The flaw
`CAP_DAC_OVERRIDE` bypasses read, **write**, and execute permission checks on
files. So `vault-write` can write to `/etc/sudoers`, `/etc/passwd`,
`/etc/shadow` — anything. The program never validates the target path.

### 3. Exploit
```bash
echo 'labuser1 ALL=(ALL) NOPASSWD:ALL' | vault-write /etc/sudoers
sudo -n bash          # or: sudo -n cat /root/flag.txt
id ; cat /root/flag.txt
```

### 4. Why it works
The subtlety: `CAP_DAC_OVERRIDE` lets you *write* a file, but a **newly
created** file is still owned by the process's uid — you. `sudo` refuses any
drop-file in `/etc/sudoers.d/` it doesn't own as root, so writing a *new*
`/etc/sudoers.d/pwn` fails the ownership check. The fix is to **append to an
existing root-owned file**: `/etc/sudoers` already exists, owned `root:root`,
mode `0440`. Appending doesn't change the owner or mode, so sudo still trusts
it — and now it carries your NOPASSWD rule. (`/etc/passwd` with an added
uid-0 line works the same way.)

### 5. Detect
```bash
getcap -r / 2>/dev/null | grep -i dac_override
# and watch for writes to sudoers/passwd/shadow by non-root processes:
auditctl -w /etc/sudoers -p wa -k sudoers_write
auditctl -w /etc/passwd  -p wa -k passwd_write
```

### 6. Harden
Remove the capability. A program that legitimately edits one config file should
have `CAP_DAC_OVERRIDE` scoped away entirely — grant it group ownership of that
one file instead, or run it under a dedicated account. Never give a generic
"write any path" tool a DAC-override capability.

### 7. Real world
Deploy tooling and "config management" helpers get `cap_dac_override` so they
can edit protected files without full root. The moment the path is
attacker-influenced (or the binary writes `/etc/sudoers`), it's root. Equivalent
to the writable-`/etc/passwd` and writable-`sudoers` classes, reached through a
capability instead of a file mode.

---

## Station E — `cap_setuid` on svc-runner  ·  ★★☆☆

### 1. Recon
`getcap -r /` → `/usr/local/bin/svc-runner cap_setuid=ep`. Not an interpreter —
a small custom binary. `strings` it, or just run it: it prints `id` output as
root by default. That "default health check" is the tell.

### 2. The flaw
`svc-runner` holds `CAP_SETUID`, calls `setuid(0)` to become root, then runs a
command taken from the `SVC_CMD` environment variable. The capability is used
correctly (it becomes root to do its job) but it then executes
**attacker-controlled** input as root.

### 3. Exploit
```bash
SVC_CMD=/bin/bash svc-runner
id ; cat /root/flag.txt
```

### 4. Why it works
Even a binary that uses `cap_setuid` "properly" is a root shell if it hands
control to something you steer. Environment variables are attacker-controlled,
so `system($SVC_CMD)` after `setuid(0)` runs your command as root. This is the
capability-flavoured cousin of PATH hijacking and `LD_PRELOAD` abuse: the power
is real, the trust boundary is the bug.

### 5. Detect
Read the source / `strings` of any capped custom binary: does it call
`system`, `exec*`, or `popen` on anything derived from argv, environment, or a
config file? Flag binaries that raise `cap_setuid` and then run external
commands.

### 6. Harden
If a helper must drop/raise privilege, it should `execve` a **fixed, absolute**
program with a sanitized environment (`clearenv()` / `execle` with a controlled
envp), never `system(getenv(...))`. Drop the capability as soon as the
privileged step is done (`cap_set_proc` to clear effective).

### 7. Real world
Bespoke setuid/cap helpers in appliances and container images routinely trust
an env var or argv to decide what to run. It's the same root cause as CVE-class
"privileged helper runs user-supplied command" bugs.

---

## Clean up / reset

Stations C–E modify the running container (`/etc/sudoers`, loot files). Reset to
pristine-vulnerable:

```bash
make reset-caps
```

Or, from your host:

```bash
docker compose up -d --build --force-recreate target-caps
```

---

## What you learned

- **`getcap -r /` is the new `find -perm -4000`.** Removing SUID bits doesn't
  remove privilege if capabilities remain. Always enumerate both.
- **Name the capability, then the primitive it gives.** `setuid` → become root;
  `dac_override` → write any file; `dac_read_search` → read any file. The
  primitive tells you the exploit.
- **"Read root's files" can be the whole win** — you don't always need a uid
  change (Station C).
- **File caps and container caps must line up.** A file capability outside the
  container's bounding set simply won't fire (Station C's `cap_add`).
- **A correctly-used capability is still a bug** if the program then runs
  attacker input (Station E).

All detection and hardening recipes are collected in the
[Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook).
