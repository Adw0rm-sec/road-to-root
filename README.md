<h1 align="center">🔓 Road to Root</h1>

<p align="center">
  <strong>Hands-on Linux privilege-escalation labs in Docker — where you <em>actually</em> get root.</strong><br/>
  <sub>4 chapters live · 18 paths to root · every exploit CI-verified end-to-end · every bug paired with the blue-team fix.</sub>
</p>

<p align="center">
  <a href="https://github.com/Adw0rm-sec/road-to-root/actions/workflows/ci.yml"><img src="https://github.com/Adw0rm-sec/road-to-root/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-Docker-2496ED?logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/focus-Linux%20privesc-444?logo=linux&logoColor=white" alt="Linux privesc">
  <img src="https://img.shields.io/badge/labs-4%20live%20%C2%B7%204%20planned-success" alt="Labs: 4 live, 4 planned">
  <img src="https://img.shields.io/badge/stations-18%20paths-success" alt="18 paths">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome">
</p>

<p align="center">
  <a href="https://github.com/Adw0rm-sec/road-to-root/wiki">
    <img src="https://img.shields.io/badge/📖_Full_Walkthroughs-Open_The_Wiki-2b7bd5?style=for-the-badge" alt="Open the Wiki">
  </a>
</p>

---

## ⚡ 60-second start

```bash
git clone https://github.com/Adw0rm-sec/road-to-root
cd road-to-root
make up                               # builds attacker + first target (Ch 01)
make attacker                         # shell into the attacker box
# inside attacker:
ssh labuser1@target-suid              # password: password123
```

You're `labuser1` on the target. Your mission on every host in the campaign:

1. **Enumerate** — understand the box you landed on.
2. **Escalate** — turn `labuser1` into `root`.
3. **Capture** — read the root-only flag to prove it: `/root/flag.txt` (format `R2R{...}`).
4. **Report** — document the path, how to detect it, how to fix it.

First moves you'll reach for in every chapter:

```bash
find / -perm -4000 -type f 2>/dev/null             # Chapter 01 surface
cat /etc/crontab /etc/cron.d/* 2>/dev/null         # Chapter 02 surface
sudo -l                                            # Chapter 03 surface
```

Stuck? The chapter READMEs have hints with increasing detail; the [wiki](https://github.com/Adw0rm-sec/road-to-root/wiki) has the full debrief per station.

---

## 🗺️ What you'll learn

- **Enumerate a box in four commands.** `sudo -l`, `find / -perm -4000`, the crontab, and `echo "$PATH"` — and read each result to know which hit opens which lab.
- **Four classes of privesc, 18 paths to root.** SUID bits, cron trust, sudo rules, and PATH hijacking — each chapter has several independent routes, so failing one never ends the box.
- **The one question under all of them.** *What does root touch that I can write?* — a file it reads, a directory it writes into, a config it sources, a command it calls by bare name. Answer it fast on any Linux host.
- **Fix every path, not just break it.** The blue-team `find`/`grep`/`auditd` one-liner and the exact permission change that kills each bug.

You land as `labuser1` (uid 1001) — not root. Four questions map the box, and each one points at a chapter:

```text
labuser1 — uid 1001, not root
│
├── sudo -l              →  a NOPASSWD rule          →  Chapter 03 · Sudo  (5 paths)
├── find / -perm -4000   →  an odd SUID binary       →  Chapter 01 · SUID  (5 paths)
├── crontab + timers     →  a timed root job         →  Chapter 02 · Cron  (5 paths)
└── echo "$PATH"         →  a writable dir on PATH    →  Chapter 04 · PATH  (3 new)

        exploit any one path  →  cat /root/flag.txt  →  R2R{…}
```

## 🗺️ Campaign roster

| # | Chapter | Host (codename) | Root cause | Difficulty | Status |
|---|---|---|---|:---:|:---:|
| 01 | **[SUID Bits](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-01-Overview)** | `target-suid` (`hollow-fileproc-01`) | Misused SUID binaries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 02 | **[Cron Jobs](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-02-Overview)** | `target-cron` (`hollow-backup-01`) | Root's timers trust the wrong things | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 03 | **[Sudo Rules](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-03-Overview)** | `target-sudo` (`hollow-dmz-01`) | Dangerous `sudoers` entries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 04 | **[PATH Hijacking](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-04-Overview)** | `target-path` (`hollow-ops-01`) | Root calls a command by name, and a writable directory is searched first | ★★☆☆ | ✅ Ready |
| 05 | Capabilities | — | `cap_setuid` on a binary | ★★★☆ | ⏳ Planned |
| 06 | Writable `/etc/passwd` | — | Weak file permissions | ★☆☆☆ | ⏳ Planned |
| 07 | NFS `no_root_squash` | — | Exported share mounts as root | ★★★☆ | ⏳ Planned |
| 08 | Docker socket | — | `/var/run/docker.sock` exposed | ★★★☆ | ⏳ Planned |

### The paths in the four live chapters

<details open>
<summary><strong>Chapter 01 — SUID Bits</strong>  ·  5 paths  ·  ★☆☆☆ → ★★★☆</summary>

- **A · GTFOBins binary** — SUID copy of `find` → `-exec /bin/sh -p` runs an arbitrary command as root
- **B · GTFOBins interpreter** — SUID copy of `python3` → write your own Python; `os.setuid(0); os.system("/bin/bash")`
- **C · PATH hijack** — custom SUID binary calls `du` by bare name; plant a fake `du` early on `$PATH`
- **D · Command injection** — custom SUID binary pastes `argv[1]` into a shell; `"x; /bin/bash -p"`
- **E · Shared-object hijack** — custom SUID binary loads `libgreet.so` from a 0777 RUNPATH dir; replace the `.so` with your own constructor

</details>

<details open>
<summary><strong>Chapter 02 — Cron Jobs</strong>  ·  5 paths  ·  ★☆☆☆ → ★★★☆</summary>

- **A · Writable cron script** — append to `/opt/maint/rotate.sh` (mode `0777`); root runs it every minute
- **B · Writable sourced config** — a locked root script `source`s `/etc/rtr/backup.conf` (mode `0666`); `source` executes the file
- **C · Writable drop directory** — root runs every `*.sh` in `/opt/jobs/` (mode `0777`); drop a new script
- **D · Cron PATH hijack** — `/etc/cron.d/rtr-health` sets `PATH=/opt/maint/bin:…` with a writable first entry; shim `df`
- **E · Tar wildcard injection** — root's `tar czf … *` inside `/opt/data/` (mode `0777`); `touch -- '--checkpoint-action=exec=sh runme.sh'`

</details>

<details open>
<summary><strong>Chapter 03 — Sudo Rules</strong>  ·  5 paths  ·  ★☆☆☆ → ★★★☆</summary>

- **A · NOPASSWD on a GTFOBins binary** — `sudo /usr/bin/find . -maxdepth 0 -exec /bin/bash \;`
- **B · NOPASSWD on a world-writable script** — `/opt/admin/backup.sh` is mode `0777`; overwrite then `sudo`-run it
- **C · `env_keep += "LD_PRELOAD"`** — sudo forwards `LD_PRELOAD`; load a `.so` whose constructor fires as root
- **D · sudoers wildcard + symlink** — `sudo cat /var/log/app/*.log` + `ln -s /root/flag.txt /var/log/app/pwn.log`
- **E · `eval` injection in a sudo'd script** — `/opt/admin/add-contact.sh` `eval`s its `argv`; `sudo … 'bob; /bin/bash'`

</details>

<details open>
<summary><strong>Chapter 04 — PATH Hijacking</strong>  ·  5 paths  ·  ★★☆☆</summary>

- **A · SUID trigger** — already on `target-suid`, Chapter 01 Station C. `logstats` calls `du` by name
- **B · Cron trigger** — already on `target-cron`, Chapter 02 Station D. The job calls `df`, and a writable directory is first on that job's `PATH`
- **C · Sudo wrapper** — `/opt/admin/disk-check.sh` is not writable. It sets `PATH` so `/opt/admin/bin` is first, then calls `df`
- **D · Service PATH** — `rtr-disk.service` sets `PATH=/opt/svc/bin:...`. A root loop runs that unit every 20 seconds. Docker does not boot systemd; the loop is the clock
- **E · `/etc/environment`** — the file is mode `0666`. A root job sources it, then calls `uname`

</details>

Every one of these has a dedicated wiki page with the exploit flag-by-flag, the mechanic, the pitfalls, and the blue-team fix:

→ **[Open the wiki →](https://github.com/Adw0rm-sec/road-to-root/wiki)**

---

## 🖥️ Running each chapter

```bash
make up                 # Chapter 01 (SUID)   attacker + target-suid
make up-cron            # Chapter 02 (Cron)   attacker + target-cron
make up-sudo            # Chapter 03 (Sudo)   attacker + target-sudo
make up-path            # Chapter 04 (PATH)   attacker + target-path

make attacker           # shell into the attacker box (all chapters)
make shell-<chapter>    # root shell on the target (inspect / reset)
make reset-<chapter>    # rebuild the target back to pristine-vulnerable
make test-<chapter>     # run the lab's self-test (CI runs these too)
make down               # tear the whole range down
```

One **attacker** box plus one vulnerable **target** per chapter, all on a shared Docker bridge network (`labnet`) so the attacker can reach targets by name (`ssh labuser1@target-suid`).

---

## 📖 The wiki — the proper way to work this range

Every station page follows the same shape, so you always know where to look:

1. **Exploit — do this first** — the working command, the `id` proof, the flag, and a token table that explains every piece
2. **How you find it** — the recon that surfaces the bug, with real output
3. **Why it works** — the kernel / sudo / cron / PATH mechanic, stated once
4. **Pitfalls** — the real traps (`-p`, the sticky bit, `LD_PRELOAD` recursion, …)
5. **Detect & fix** — the blue-team check and the permission change (full recipes in the Playbook)
6. **What you learned** — the transferable lesson that ports to every future box

Plus cross-cutting reference pages:

- [The Map](https://github.com/Adw0rm-sec/road-to-root/wiki/Methodology-Map) — the decision tree: match what enumeration shows you to the station that exploits it
- [SUID Privesc Reference](https://github.com/Adw0rm-sec/road-to-root/wiki/SUID-Privesc-Reference) — `s`/`S`/`t` bit chart, GTFOBins primer, AT_SECURE, RUNPATH deep dive
- [Cron Privesc Reference](https://github.com/Adw0rm-sec/road-to-root/wiki/Cron-Privesc-Reference) — every path cron hides on Linux + the 5+2 recon questions
- [Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook) — all detect + fix recipes in one place, for every chapter
- [Glossary](https://github.com/Adw0rm-sec/road-to-root/wiki/Glossary) — SUID / SGID / sticky / RUNPATH / `euid` vs `uid` / drop dir
- [FAQ & Troubleshooting](https://github.com/Adw0rm-sec/road-to-root/wiki/FAQ-And-Troubleshooting) — the Docker, cron-timing, sticky-bit gotchas
- [Contributing New Chapters](https://github.com/Adw0rm-sec/road-to-root/wiki/Contributing-New-Chapters) — the template every lab follows

→ **[Full Wiki index →](https://github.com/Adw0rm-sec/road-to-root/wiki)**

---

## ⚖️ Legal & ethics

This range exists **only** to teach defence through hands-on offence. Everything here is intentionally vulnerable and meant to run **locally, in throwaway containers, on hardware you own**.

- **Do not** expose these containers to the internet or any network you don't control.
- **Do not** use these techniques on systems you aren't explicitly authorised to test.
- Exploits are deliberately simplified for learning; real engagements require written authorisation and scope.

Unauthorised access to computer systems is a crime. You are responsible for how you use this. See [LICENSE](LICENSE).

---

## 🧱 What a container can't do

Containers share the **host kernel**, so true kernel exploits (Dirty COW, Dirty Pipe, `pwnkit`-style ring-0 bugs) can't be practised safely here — they'd need their own kernel. For those, keep a small old-kernel VM. Everything in the roster above is user-space misconfiguration and lives happily in Docker.

---

## 🤝 Contributing

Add your own chapter: the lab template and the contract every chapter follows live in **[docs/LAB_TEMPLATE.md](docs/LAB_TEMPLATE.md)** and the wiki's **[Contributing New Chapters](https://github.com/Adw0rm-sec/road-to-root/wiki/Contributing-New-Chapters)**. Issues and PRs welcome.

Full campaign lore, personae and design principles live in **[docs/CAMPAIGN.md](docs/CAMPAIGN.md)**.
