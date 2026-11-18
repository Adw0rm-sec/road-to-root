# Chapter 05 — "Capabilities"  ·  File-capability Privilege Escalation

> **Host:** `hollow-vault-01` (compose service `target-caps`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★★☆ (no SUID bits — you have to look one layer deeper)

---

## Mission brief

Hollow Industries' vault host was "hardened": the admins removed the SUID bit
from everything and patted themselves on the back. `find / -perm -4000` is a
dead end here. But SUID is only one way a program runs with power.

Since Linux 2.2, root's authority is split into ~40 **capabilities**, and a
single one can be pinned onto a file. A binary with `cap_setuid` can turn into
uid 0. One with `cap_dac_override` can write any file. One with
`cap_dac_read_search` can read any file. The bit is gone; the power isn't.

> **The whole idea in one line:** `getcap -r /` is the new `find -perm -4000`.
> A capability is a slice of root welded to a file — find the binary that
> carries one and lets you steer it.

---

## Objective and rules

- **Win condition:** read `/root/flag.txt`. Flag format: `R2R{...}`.
- **In scope:** this container only.
- **Connect:** from the attacker box, `ssh labuser1@target-caps` (password `password123`).
  Or `docker exec -it -u labuser1 target-caps bash`.
- Five independent paths. One is enough to win. Map all five, and **name the
  capability** behind each.

---

## Recon starter

```bash
getcap -r / 2>/dev/null          # the whole surface, one command
# then, for each hit:
getcap /usr/local/bin/pyvault    # which capability, and is it +ep (effective)?
```

For every binary it lists, ask two questions: *what does this capability let
the holder do?* and *does the binary let me choose what it does with it?*

---

## Stations

| Station | Binary | Capability | What it buys you |
|---|---|---|---|
| A | `pyvault` (python3 copy) | `cap_setuid` | become uid 0 from inside Python |
| B | `plvault` (perl copy) | `cap_setuid` | become uid 0 from inside Perl |
| C | `captar` (tar copy) | `cap_dac_read_search` | **read** any file — no shell, just the flag |
| D | `vault-write` (custom) | `cap_dac_override` | **write/append** any root file → sudoers → root |
| E | `svc-runner` (custom) | `cap_setuid` | a launcher that `setuid(0)`s then runs *your* command |

> Note: `cap_dac_read_search` is **not** in Docker's default capability set, so
> the lab adds it to the container (`cap_add: [DAC_READ_SEARCH]`). On a real
> host the capability simply sits on the file. The other four work with no
> extra grants — they're all in Docker's default set. That gap is itself the
> lesson of Station C: see the debrief.

---

## Hints

<details><summary>Stations A &amp; B — cap_setuid on an interpreter</summary>

The interpreter can call `setuid(0)` for you — the capability makes the call
succeed. After that, spawn a shell. Python: `os.setuid(0)` then `os.system`.
Perl: `POSIX::setuid(0)` then `exec`. Watch the `gid` in `id` — `cap_setuid`
sets the uid, not the gid; it's still a root uid, which is all you need.

</details>

<details><summary>Station C — cap_dac_read_search on tar</summary>

This one does **not** give you a shell. `cap_dac_read_search` bypasses read
and directory-search checks, so `captar` can archive a file you can't read.
Archive `/root/flag.txt`, extract the archive somewhere you own, and read your
copy. GTFOBins "tar" + "Capabilities" is the pattern.

</details>

<details><summary>Station D — cap_dac_override on a writer</summary>

`vault-write <path>` appends your stdin to any file. A brand-new file would be
owned by you (and sudo rejects drop-files it doesn't own) — so append to a
file that is **already** root-owned. `/etc/sudoers` is right there. Add a
NOPASSWD rule for yourself, then `sudo`.

</details>

<details><summary>Station E — cap_setuid on svc-runner</summary>

Read what it runs. It becomes root, then executes whatever `$SVC_CMD` says.
Set `SVC_CMD` to a shell.

</details>

---

## Capture

```bash
id
cat /root/flag.txt
```

The debrief — each capability explained, detection, and the fix — is in
[WRITEUP.md](WRITEUP.md). Try the box before you open it.
