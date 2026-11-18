# Chapter 05 — "Capabilities"

> **Host:** `hollow-vault-01` (compose service `target-caps`)
> **Foothold:** `labuser1 : password123` · **Objective:** root, read `/root/flag.txt`
> **Difficulty:** ★★★☆
> **Flag:** `/root/flag.txt` → `R2R{c4p4b1l1t1es_are_suid_without_the_b1t}`

New to the range? Read [[Getting-Started]] and [[How-A-Chapter-Works]] first.

## Mission brief

The vault host was "hardened" by stripping SUID bits, so `find / -perm -4000`
is a dead end. But SUID is only one way a program runs with power. Linux splits
root's authority into ~40 **capabilities** (`capabilities(7)`), and a single one
can be welded to a file with `setcap`. The bit is gone; the power isn't.

> **The whole idea in one line:** `getcap -r /` is the new `find -perm -4000`. A
> capability is a slice of root pinned to a binary — find the one you can steer.

## The capability sets

`setcap cap_setuid+ep file` puts the capability in both the **permitted** (`p`)
and **effective** (`e`) sets, so it's live the instant the binary runs. That
`+ep` is the dangerous part.

## Recon starter

```bash
getcap -r / 2>/dev/null
# /usr/local/bin/pyvault    cap_setuid=ep
# /usr/local/bin/plvault    cap_setuid=ep
# /usr/local/bin/captar     cap_dac_read_search=ep
# /usr/local/bin/vault-write cap_dac_override=ep
# /usr/local/bin/svc-runner cap_setuid=ep
```

For each hit ask: *what does this capability allow, and does the binary let me
choose what it does with it?*

## The five stations

| # | Binary | Capability | What it buys you | Difficulty |
|---|---|---|---|:---:|
| [[A\|C05-Station-A-cap_setuid-python]] | `pyvault` | `cap_setuid` | `setuid(0)` → root shell | ★★☆☆ |
| [[B\|C05-Station-B-cap_setuid-perl]] | `plvault` | `cap_setuid` | `setuid(0)` → root shell | ★★☆☆ |
| [[C\|C05-Station-C-cap_dac_read_search-tar]] | `captar` | `cap_dac_read_search` | read any file — **no shell** | ★★★☆ |
| [[D\|C05-Station-D-cap_dac_override-write]] | `vault-write` | `cap_dac_override` | write any root file → sudoers | ★★★☆ |
| [[E\|C05-Station-E-cap_setuid-launcher]] | `svc-runner` | `cap_setuid` | `setuid(0)` then runs `$SVC_CMD` | ★★☆☆ |

## How to connect

```bash
make up-caps
make attacker
ssh labuser1@target-caps        # password123
```

## How to reset

```bash
make reset-caps
```

## The through-line

Enumerate capabilities as carefully as SUID bits. Name the capability, then the
primitive it hands you. One station (C) proves you don't always need a uid
change — reading root's files can be the whole win. Full detection and
hardening in [[Blue-Team-Playbook]]; the repo debrief is
[`targets/caps/WRITEUP.md`](https://github.com/Adw0rm-sec/road-to-root/blob/main/targets/caps/WRITEUP.md).

## Next

Start with [[C05-Station-A-cap_setuid-python]], then the harder read/write caps.
