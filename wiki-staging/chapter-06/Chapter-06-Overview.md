# Chapter 06 — "Wildcard Expansion"

> **Host:** `hollow-archive-01` (compose service `target-wild`)
> **Foothold:** `labuser1 : password123` · **Objective:** root, read `/root/flag.txt`
> **Difficulty:** ★★☆☆ → ★★★☆
> **Flag:** `/root/flag.txt` → `R2R{the_shell_expands_star_before_the_program_sees_it}`

New to the range? Read [[Getting-Started]] and [[How-A-Chapter-Works]] first.

## Mission brief

Root's housekeeping runs every minute and every job ends in an unquoted `*`.
The **shell** expands `*` into filenames *before* the command runs, so a file
named like an option *becomes* an option. You pick the filenames in those
directories — so you write part of root's command line.

> **The whole idea in one line:** `tar czf backup *` becomes
> `tar czf backup --checkpoint-action=exec=sh evil.sh …` the moment that
> filename exists in the directory.

You met a taste of this in [[C02-Station-E-Tar-Wildcard-Injection]]. This host
is the deep dive: four tools, four injections.

## Two preconditions, every time

1. an **unquoted glob** (`*`) in a privileged command, and
2. a directory **you can write**.

Kill either and the bug dies.

## Recon starter

```bash
cat /etc/cron.d/rtr-*            # every job + schedule + user
cat /usr/local/sbin/*-run.sh     # the actual command each runs
ls -ld /opt/archive /opt/sync /opt/pipeline /opt/conf
```

Create option-named files with `touch -- "--option..."` (the `--` stops `touch`
from parsing the dashes).

## The four stations

| # | Tool | Injected option | Result | Difficulty |
|---|---|---|---|:---:|
| [[A\|C06-Station-A-tar-checkpoint]] | `tar czf … *` | `--checkpoint-action=exec=sh runme.sh` | RCE | ★★☆☆ |
| [[B\|C06-Station-B-rsync-e]] | `rsync -a * host:` | `-e sh payload.sh` | RCE | ★★☆☆ |
| [[C\|C06-Station-C-chown-reference]] | `chown -R root:root *` | `--reference=ref` | own a root script → root | ★★★☆ |
| [[D\|C06-Station-D-chmod-reference]] | `chmod -R 700 *` | `--reference=ww` | open a root script → root | ★★★☆ |

A and B give RCE outright. C and D hand you a root-owned script the same job
runs — the drop dirs are **sticky** (`1777`), so you can't delete or edit that
script directly, but a planted `--reference` makes `chown`/`chmod` do it for you.

## How to connect / reset

```bash
make up-wild
make attacker
ssh labuser1@target-wild        # password123
# ...
make reset-wild
```

## The through-line

Never glob with a bare `*` in a privileged job — use `./*`, an explicit list, or
`--`. And never share a directory between "users write here" and "root runs
this." Detection and fixes in [[Blue-Team-Playbook]]; the repo debrief is
[`targets/wild/WRITEUP.md`](https://github.com/Adw0rm-sec/road-to-root/blob/main/targets/wild/WRITEUP.md).

## Next

Start with [[C06-Station-A-tar-checkpoint]].
