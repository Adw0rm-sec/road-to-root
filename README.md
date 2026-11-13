# Road to Root — Linux Privilege Escalation Labs

<p align="center">
  <a href="https://github.com/Adw0rm-sec/road-to-root/actions/workflows/ci.yml"><img src="https://github.com/Adw0rm-sec/road-to-root/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-Docker-2496ED?logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/focus-Linux%20privesc-444?logo=linux&logoColor=white" alt="Linux privesc">
  <img src="https://img.shields.io/badge/labs-3%20live%20%C2%B7%205%20planned-success" alt="Labs: 3 live, 5 planned">
  <a href="https://github.com/Adw0rm-sec/road-to-root/wiki"><img src="https://img.shields.io/badge/docs-wiki-blue" alt="Wiki"></a>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome">
</p>

> A hands-on, story-driven Linux privilege-escalation range you run on your own
> machine with Docker. You get a low-privilege foothold on a box; your job is to
> become **root**. Every lab is a real misconfiguration you'll meet in the wild,
> planted on purpose, documented end-to-end — from the mistake, to the exploit,
> to how a blue team would **detect and fix** it.

<p align="center">
  <i>Learn privesc by doing it, not by reading about it.</i>
</p>

---

## The story

You're an operator on a red-team engagement for **BlackReef Security**. The
client — **Hollow Industries**, a logistics and data company — wants to know how
far an attacker gets *after* the first foothold. Phishing already got you a
low-privilege SSH account on their internal hosts. That's where you start.

Standing orders for every host in the campaign:

1. **Enumerate** — understand the box you landed on.
2. **Escalate** — turn `labuser1` into `root`.
3. **Capture** — read the root-only flag to prove it: `/root/flag.txt`.
4. **Report** — document the path, how to detect it, and how to fix it.

Each chapter is one compromised host with a different **root cause**. Full
campaign lore and the chapter roster live in **[docs/CAMPAIGN.md](docs/CAMPAIGN.md)**.

> 📖 **Deep walkthroughs for every station** — mission brief, recon, exploit
> flag-by-flag, mechanic, pitfalls, blue-team detect + fix — live in the
> [**Road to Root Wiki**](https://github.com/Adw0rm-sec/road-to-root/wiki).

---

## Campaign roster

| # | Chapter | Host (codename) | Root cause | Difficulty | Status |
|---|---------|-----------------|-----------|:----------:|:------:|
| 01 | **SUID Bits** | `target-suid` (hollow-fileproc-01) | Misused SUID binaries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 02 | **Cron Jobs** | `target-cron` (hollow-backup-01) | Root's timers trust the wrong things | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 03 | **Sudo Rules** | `target-sudo` (hollow-dmz-01) | Dangerous `sudoers` entries | ★☆☆☆ → ★★★☆ | ✅ Ready |
| 04 | PATH & env | — | Untrusted `$PATH` in root context | ★★☆☆ | ⏳ Planned |
| 05 | Capabilities | — | `cap_setuid` on a binary | ★★★☆ | ⏳ Planned |
| 06 | Writable `/etc/passwd` | — | Weak file permissions | ★☆☆☆ | ⏳ Planned |
| 07 | NFS `no_root_squash` | — | Exported share mounts as root | ★★★☆ | ⏳ Planned |
| 08 | Docker socket | — | `/var/run/docker.sock` exposed | ★★★☆ | ⏳ Planned |

> We grow this one chapter at a time: build the box → test it locally → confirm
> it works as intended → publish. Three chapters live; the rest land as they're verified.

### What each live chapter teaches

Every chapter is **one host**, **one class of flaw**, and **five independent root paths** inside it — so you can fail one and still win. The sub-stations:

<details open>
<summary><strong>Chapter 01 — SUID Bits</strong> · ★☆☆☆ → ★★★☆</summary>

- **A · GTFOBins binary** — SUID copy of `find` → `-exec /bin/sh -p` runs an arbitrary command as root
- **B · GTFOBins interpreter** — SUID copy of `python3` → write your own Python; `os.setuid(0); os.system("/bin/bash")`
- **C · PATH hijack** — custom SUID binary calls `du` by bare name; plant a fake `du` early on `$PATH`
- **D · Command injection** — custom SUID binary pastes `argv[1]` into a shell; `"x; /bin/bash -p"`
- **E · Shared-object hijack** — custom SUID binary loads `libgreet.so` from a 0777 RPATH dir; replace the `.so` with your own constructor

</details>

<details open>
<summary><strong>Chapter 02 — Cron Jobs</strong> · ★☆☆☆ → ★★★☆</summary>

- **A · Writable cron script** — append to `/opt/maint/rotate.sh` (mode `0777`); root runs it every minute
- **B · Writable sourced config** — a locked root script `source`s `/etc/rtr/backup.conf` (mode `0666`); `source` executes the file
- **C · Writable drop directory** — root runs every `*.sh` in `/opt/jobs/` (mode `0777`); drop a new script
- **D · Cron PATH hijack** — `/etc/cron.d/rtr-health` sets `PATH=/opt/maint/bin:…` with a writable first entry; shim `df`
- **E · Tar wildcard injection** — root's `tar czf … *` inside `/opt/data/` (mode `0777`); `touch -- '--checkpoint-action=exec=sh pwn.sh'`

</details>

<details open>
<summary><strong>Chapter 03 — Sudo Rules</strong> · ★☆☆☆ → ★★★☆</summary>

- **A · NOPASSWD on a GTFOBins binary** — `sudo /usr/bin/find . -maxdepth 0 -exec /bin/bash \;`
- **B · NOPASSWD on a world-writable script** — `/opt/admin/backup.sh` is mode `0777`; overwrite then `sudo`-run it
- **C · `env_keep += "LD_PRELOAD"`** — sudo forwards `LD_PRELOAD`; load a `.so` whose constructor fires as root
- **D · sudoers wildcard + symlink** — `sudo cat /var/log/app/*.log` + `ln -s /root/flag.txt /var/log/app/pwn.log`
- **E · `eval` injection in a sudo'd script** — `/opt/admin/add-contact.sh` `eval`s its `argv`; `sudo … 'bob; /bin/bash'`

</details>

Deeper per-station walkthroughs (mission brief, recon, exploit flag-by-flag, mechanic, pitfalls, blue-team detect + fix) live in the [**Road to Root Wiki**](https://github.com/Adw0rm-sec/road-to-root/wiki).

---

## How the range is built

One **attacker** box plus one vulnerable **target** per attack type, all on a
shared Docker bridge network (`labnet`) so the attacker can reach targets by name.

```
road-to-root/
├── docker-compose.yml      # wires attacker + targets on 'labnet'
├── attacker/               # your kit: nmap, linpeas, LES, prefetched
├── targets/
│   ├── suid/               # CHAPTER 01 — SUID bits (ready)
│   │   ├── README.md       #   mission brief  (try it yourself)
│   │   └── WRITEUP.md      #   full walkthrough (spoilers)
│   ├── cron/               # CHAPTER 02 — cron jobs (ready)
│   │   ├── README.md       #   mission brief
│   │   └── WRITEUP.md      #   full walkthrough
│   └── sudo/               # CHAPTER 03 — sudo rules (ready)
│       ├── README.md       #   mission brief
│       └── WRITEUP.md      #   full walkthrough
└── docs/
    ├── CAMPAIGN.md         # the story + roster
    └── LAB_TEMPLATE.md     # the template every lab follows
```

## Quick start

```bash
# Build and start the attacker + the SUID target
docker compose up -d --build attacker target-suid

# Hop onto your attacker box
docker exec -it attacker bash

# From the attacker, reach the target by name and log in
ssh labuser1@target-suid          # password: password123
```

You're now `labuser1` on the target. Open **[targets/suid/README.md](targets/suid/README.md)**
and start the mission. Stuck? The full walkthrough is in
**[targets/suid/WRITEUP.md](targets/suid/WRITEUP.md)**.

Handy shortcuts (see the [Makefile](Makefile)):

```bash
make up          # build + start attacker and target-suid
make attacker    # shell into the attacker box
make reset-suid  # rebuild the SUID target back to pristine-vulnerable
make down        # tear the range down
```

---

## ⚠️ Legal & ethics

This range exists **only** to teach defense through hands-on offense. Everything
here is intentionally vulnerable and meant to run **locally, in throwaway
containers, on hardware you own**.

- **Do not** expose these containers to the internet or any network you don't control.
- **Do not** use these techniques on systems you aren't explicitly authorized to test.
- The exploits are deliberately simplified for learning; real engagements require
  written authorization and scope.

Unauthorized access to computer systems is a crime. You are responsible for how
you use this. See [LICENSE](LICENSE).

---

## What can't be done in a container

Containers share the **host kernel**, so true kernel exploits (e.g. Dirty COW,
Dirty Pipe, `pwnkit`-style ring-0 bugs) can't be practiced safely here — they'd
need their own kernel. For those, keep a small old-kernel VM. Everything in the
roster above is user-space misconfiguration and lives happily in Docker.
