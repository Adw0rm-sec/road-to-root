# Road to Root

A hands-on, story-driven Linux privilege-escalation range you run on your own
machine with Docker. You start with a low-privilege foothold on a target; your
job is to become **root** — then write up what you did, how a defender would
catch it, and how they would fix it.

## The engagement

You're an operator for **BlackReef Security**, running a red-team engagement
against the client, **Hollow Industries**. Phishing already got you a standard
user account — `labuser1 / password123` — on their internal boxes, so your
work starts *after* the foothold, not before it. Prove how far an attacker
climbs on each host by reading the root-only flag at `/root/flag.txt`, format
`R2R{...}`.

Every chapter is one compromised host with one class of flaw and several
independent paths to root inside it, so you can fail one and still win.

## Quick start

Clone the repo, bring the range up, and SSH into the first target from the
attacker box:

```bash
git clone https://github.com/Adw0rm-sec/road-to-root
cd road-to-root
make up                                # attacker + target-suid
make attacker                          # shell on attacker
# inside attacker:
ssh labuser1@target-suid               # password: password123
```

`make up` builds and starts two containers on a private Docker bridge network
called `labnet`: the attacker container (with `nmap`, `linpeas`, LES and a few
other staples prefetched) and the `target-suid` box for Chapter 01. `make
attacker` drops you into a shell on the attacker. From there `target-suid`
resolves by name because both containers share `labnet`.

When you're done, `make down` tears the range down. Need a clean slate on a
target you've already broken? `make reset-suid` rebuilds it back to
pristine-vulnerable.

## Campaign roster

| # | Chapter | Root cause | Difficulty | Status |
|---|---|---|:---:|:---:|
| 01 | SUID Bits | Misused SUID binaries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 02 | Cron Jobs | Root's timers trust the wrong things | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 03 | Sudo Rules | Dangerous `sudoers` entries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 04 | [[PATH Hijacking\|Chapter-04-Overview]] | Root calls a command by name, and a writable directory is searched first | ★★☆☆ | ✅ Ready |
| 05 | Capabilities | `cap_setuid` on a binary | ★★★☆ | ⏳ Planned |
| 06 | Writable `/etc/passwd` | Weak file permissions | ★☆☆☆ | ⏳ Planned |
| 07 | NFS `no_root_squash` | Exported share mounts as root | ★★★☆ | ⏳ Planned |
| 08 | Docker socket | `/var/run/docker.sock` exposed | ★★★☆ | ⏳ Planned |
| 09 | [[Foothold — Web RCE\|Chapter-09-Overview]] | A vulnerable web app → RCE → reverse shell → root | ★☆☆☆ → ★★★☆ | ✅ Ready |

Five chapters are live today; the rest land one at a time, each one only
after it has been built and run end-to-end on a clean host. See
[[The-Campaign-Bible]] for the in-world lore and the design rules every
chapter follows.

## What each live chapter teaches

Every chapter is **one host**, **one class of flaw**, and **five independent root paths** inside it — so you can fail one and still win. The sub-stations:

### [[Chapter 01 — SUID Bits|Chapter-01-Overview]]  ·  ★☆☆☆ → ★★★☆

- **A · GTFOBins binary** — SUID copy of `find` → `-exec /bin/sh -p` runs an arbitrary command as root ([[C01-Station-A-GTFOBins-find]])
- **B · GTFOBins interpreter** — SUID copy of `python3` → write your own Python; `os.setuid(0); os.system("/bin/bash")` ([[C01-Station-B-GTFOBins-python]])
- **C · PATH hijack** — custom SUID binary calls `du` by bare name; plant a fake `du` early on `$PATH` ([[C01-Station-C-PATH-Hijack]])
- **D · Command injection** — custom SUID binary pastes `argv[1]` into a shell; `"x; /bin/bash -p"` ([[C01-Station-D-Command-Injection]])
- **E · Shared-object hijack** — custom SUID binary loads `libgreet.so` from a 0777 RPATH dir; replace the `.so` with your own constructor ([[C01-Station-E-Shared-Object-Hijack]])

### [[Chapter 02 — Cron Jobs|Chapter-02-Overview]]  ·  ★☆☆☆ → ★★★☆

- **A · Writable cron script** — append to `/opt/maint/rotate.sh` (mode `0777`); root runs it every minute ([[C02-Station-A-Writable-Cron-Script]])
- **B · Writable sourced config** — a locked root script `source`s `/etc/rtr/backup.conf` (mode `0666`); `source` executes the file ([[C02-Station-B-Writable-Sourced-Config]])
- **C · Writable drop directory** — root runs every `*.sh` in `/opt/jobs/` (mode `0777`); drop a new script ([[C02-Station-C-Writable-Drop-Dir]])
- **D · Cron PATH hijack** — `/etc/cron.d/rtr-health` sets `PATH=/opt/maint/bin:…` with a writable first entry; shim `df` ([[C02-Station-D-Cron-PATH-Hijack]])
- **E · Tar wildcard injection** — root's `tar czf … *` inside `/opt/data/` (mode `0777`); `touch -- '--checkpoint-action=exec=sh pwn.sh'` ([[C02-Station-E-Tar-Wildcard-Injection]])

### [[Chapter 03 — Sudo Rules|Chapter-03-Overview]]  ·  ★☆☆☆ → ★★★☆

- **A · NOPASSWD on a GTFOBins binary** — `sudo /usr/bin/find . -maxdepth 0 -exec /bin/bash \;` ([[C03-Station-A-GTFOBins-sudo-find]])
- **B · NOPASSWD on a world-writable script** — `/opt/admin/backup.sh` is mode `0777`; overwrite then `sudo`-run it ([[C03-Station-B-Writable-Sudo-Script]])
- **C · `env_keep += "LD_PRELOAD"`** — sudo forwards `LD_PRELOAD`; load a `.so` whose constructor fires as root ([[C03-Station-C-LD_PRELOAD-env_keep]])
- **D · sudoers wildcard + symlink** — `sudo cat /var/log/app/*.log` + `ln -s /root/flag.txt /var/log/app/pwn.log` ([[C03-Station-D-Sudo-Wildcard-Symlink]])
- **E · `eval` injection in a sudo'd script** — `/opt/admin/add-contact.sh` `eval`s its `argv`; `sudo … 'bob; /bin/bash'` ([[C03-Station-E-Eval-Injection]])

### [[Chapter 04 — PATH Hijacking|Chapter-04-Overview]]  ·  ★★☆☆

- **A · SUID trigger** — `logstats` calls `du` by name. Play it on the SUID host ([[C04-Station-A-SUID-PATH]], full notes on [[C01-Station-C-PATH-Hijack]])
- **B · Cron trigger** — cron's `PATH` lists a writable directory first, then the job calls `df` ([[C04-Station-B-Cron-PATH]], full notes on [[C02-Station-D-Cron-PATH-Hijack]])
- **C · Sudo wrapper** — the script is not writable. It sets `PATH` so `/opt/admin/bin` is first, then calls `df` ([[C04-Station-C-Sudo-Wrapper-PATH]])
- **D · Service PATH** — the unit sets `PATH=/opt/svc/bin:...`. A root loop runs it every 20 seconds ([[C04-Station-D-Service-PATH]])
- **E · `/etc/environment`** — mode `0666`. A root job sources it, then calls `uname` ([[C04-Station-E-Etc-Environment]])

### [[Chapter 09 — Foothold (Web RCE)|Chapter-09-Overview]]  ·  ★☆☆☆ → ★★★☆

The one chapter that starts you **outside** — no shell, just a browser + Burp against the "Hollow Share" portal. Six routes to code execution, each landing a reverse shell as `www-data`, then `sudo php` to root.

- **A · Unrestricted upload** — drop `shell.php` in a web-served dir, request it ([[C09-Station-A-Unrestricted-Upload]])
- **B · Upload filter bypass** — `.pht`/`.php5`, double extension, GIF89a + spoofed `image/gif`, `.htaccess` ([[C09-Station-B-Upload-Filter-Bypass]])
- **C · OS command injection** — the ping tool splices `host` into a shell ([[C09-Station-C-Command-Injection]])
- **D · LFI → RCE** — `?page=` includes any file; log poisoning + `php://filter`/`data://`/`php://input` ([[C09-Station-D-LFI-RCE]])
- **E · SSTI (Twig)** — a greeting preview compiles your input; `{{7*7}}` → `{{['id']|map('system')}}` ([[C09-Station-E-SSTI-Twig]])
- **F · PHP deserialization** — the `prefs` cookie is `unserialize()`d; a `__wakeup()` gadget ([[C09-Station-F-PHP-Deserialization]])

Reverse shells are the teaching point — catalog, TTY upgrade, and listeners on [[Reverse-Shell-Reference]].

## What you'll learn

- **Enumerate SUID anywhere.** Read a listing fast, spot the `-rws` bit, and
  know which SUID files are normal and which are not.
- **Exploit five cron patterns.** Writable scripts, writable sourced configs,
  writable drop directories, cron `$PATH` hijack, and the `tar *` wildcard
  trick — all driven by one root timer.
- **Win a PATH search.** A short name is looked up left to right. Put your file in the first writable directory a root caller searches: setuid, cron, a sudo script, a service unit, or `/etc/environment`.
- **Audit sudo like a defender.** Five classes of sudoers mistake — GTFOBins
  binaries, writable scripts, `env_keep` code-loaders, wildcard+symlink,
  argv injection via `eval` — and the one-liner `sudo -l` recon that surfaces
  each one.
- **Detect and fix each path, not just break it.** Every chapter ships with a
  blue-team section: the log line, audit rule, `find` sweep, or permissions
  change that would have killed the bug.
- **FHS literacy.** Where root-owned code lives (`/usr/local/bin`,
  `/etc/cron.d`, `/etc/sudoers.d`, `/opt`), what lives in `/tmp` and why
  you should not trust it, and how `$PATH` resolution turns a bad entry
  into code execution.
- **Think like an attacker on timer-based, permissions-based, and
  delegation-based bugs.** The pattern is always the same: find the writable
  thing — or the controllable input — that a higher-privileged process trusts.

## Where to start

New to the range? Read [[Getting-Started]] first. It covers the prerequisites
(Docker, `make`, a few GB of disk), the Makefile shortcuts, the SSH login,
where the flags live on each box, and how to reset a target when you've
clobbered it.

## Suggested learning path

If you're new, work through the wiki in this order: [[Getting-Started]] →
[[Chapter-01-Overview]] (the five SUID stations, start with
[[C01-Station-A-GTFOBins-find]]) → [[Chapter-02-Overview]] (the five cron
stations, start with [[C02-Station-A-Writable-Cron-Script]]) →
[[Chapter-03-Overview]] (the five sudo stations, start with
[[C03-Station-A-GTFOBins-sudo-find]]) → [[Chapter-04-Overview]] (PATH hijacking, start with
[[C04-Station-C-Sudo-Wrapper-PATH]]) → [[Cron-Privesc-Reference]] and
[[SUID-Privesc-Reference]] (the patterns across all paths) →
[[Blue-Team-Playbook]] (how a defender would have caught each one). After
that, [[Glossary]] and [[References-And-Further-Reading]] are good to keep
open while you hunt. Stuck or seeing something odd?
[[FAQ-And-Troubleshooting]] covers the usual ones.

## Repo

Source, Dockerfiles, writeups and the Makefile live at
<https://github.com/Adw0rm-sec/road-to-root>. Contributions are welcome — see
[[Contributing-New-Chapters]] for the template every lab follows.
