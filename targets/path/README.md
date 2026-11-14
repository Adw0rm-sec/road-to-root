# Chapter 04 — "PATH Hijacking"  ·  PATH Privilege Escalation

> **Host:** `hollow-ops-01` (compose service `target-path`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★☆☆ (three new paths; two you have already done elsewhere)

---

## Mission brief

Hollow Industries' ops host runs disk checks and a login-style status job.
None of those programs contain your code. Each one calls a command by its
short name, and the folder searched first is one you can write.

Stations A and B are the same idea on hosts you already own:

- **A** — setuid program calls `du`. Play it on `target-suid`, Chapter 01 Station C.
- **B** — cron calls `df`. Play it on `target-cron`, Chapter 02 Station D.

This host is stations C, D, and E.

> **The whole idea in one line:** when root runs `df` with no slash, the
> first `df` on `PATH` wins, and that file runs as root.

---

## Objective and rules

- **Win condition:** read `/root/flag.txt`. Flag format: `R2R{...}`.
- **In scope:** this container only.
- **Connect:** from the attacker box, `ssh labuser1@target-path` (password `password123`).
  Or `docker exec -it -u labuser1 target-path bash`.
- Three independent paths. One is enough to win. Map all three.
- Stations D and E tick about every 20 seconds. A shell from those ticks
  dies with the job, so copy bash out first:

```bash
cp /bin/bash /tmp/rb && chmod 6777 /tmp/rb
/tmp/rb -p
```

---

## Recon starter

```bash
echo "$PATH"
sudo -l
ls -ld /opt/admin /opt/admin/bin /opt/svc /opt/svc/bin
ls -l /etc/environment /etc/systemd/system/rtr-disk.service
```

For each root program, find the command it calls with no `/` in the name,
then read the `PATH` that program will actually search.

---

## Stations

| Station | Where | What you are looking for |
|---|---|---|
| A | `target-suid` | setuid binary calls `du` by name |
| B | `target-cron` | cron calls `df`, and a writable dir is first on that job's `PATH` |
| C | this host | `sudo -l` names a script. The script is not writable. It sets `PATH` and calls `df` |
| D | this host | `/etc/systemd/system/rtr-disk.service` sets `PATH`. A root loop runs that unit every 20 seconds. Docker does not boot systemd; the loop is the clock, the unit file is the bug |
| E | this host | `/etc/environment` is writable. A root job sources it, then calls `uname` |

---

## Hints

<details><summary>Station C — sudo wrapper</summary>

`sudo -l` shows one script. `ls -l` that script: you cannot edit it.
Read it. It exports a `PATH` and then runs a command with no slash.
`ls -ld` the first directory on that `PATH`.

</details>

<details><summary>Station D — service PATH</summary>

Open `/etc/systemd/system/rtr-disk.service`. The `Environment=PATH` line
is the search path the clock uses. `ExecStart` is a root-owned script.
Read the script and see which short name it calls. The first directory
on the unit `PATH` is writable. The clock is about 20 seconds.

</details>

<details><summary>Station E — /etc/environment</summary>

`ls -l /etc/environment`. If you can write it, a root job sources that
file and then runs `uname` with no slash. Put a directory you control
first, and leave the normal system directories after it so the rest of
the path still works. Wait for the next tick.

</details>

---

## Capture

```bash
id
cat /root/flag.txt
```

The debrief, including detection and the fix, is in [WRITEUP.md](WRITEUP.md).
Try the box before you open it.
