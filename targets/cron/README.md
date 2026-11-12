# Chapter 02 — "The 60-Second Window"  ·  Cron Privilege Escalation

> **Host:** `hollow-backup-01` (compose service `target-cron`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★☆☆☆ → ★★★☆ (five paths, easy to medium)

---

## 📻 Mission brief

Hollow Industries' nightly **backup server** runs itself. Scheduled jobs tidy
logs, archive data and ship backups around the clock — and nobody has logged in
for weeks. That's the problem: the automation leans on scripts, configs and
directories whose permissions quietly rotted, and no human was watching.

Intel says this box leans on **cron**. A cron job runs with the privileges of
whoever **owns the schedule** — here, `root`. So if you can change *what one of
those jobs does*, you change what **root** does, automatically, on the next tick.

> **The whole idea in one line:** a scheduled job is root's code on a timer — if
> you can write the file, directory, config, or command it reaches for, *you*
> decide what root runs.

---

## 🎯 Objective & rules of engagement

- **Win condition:** read `/root/flag.txt` (only root can). Flag format: `R2R{...}`.
- **In scope:** this container only. Everything you need is on the box.
- **Connect:** from the attacker box, `ssh labuser1@target-cron` (password `password123`).
  Or jump straight in: `docker exec -it -u labuser1 target-cron bash`.
- There are **five independent paths** to root. You need one to win; try to map all five.

### ⏱️ Patience is the tool

cron here fires **every minute**. The loop for every path is the same:

1. **Plant** your payload (edit a file / drop a file / craft a filename).
2. **Wait** up to **60 seconds** for the next tick.
3. **Collect** your root (a root shell, or the flag).

If nothing happened, re-check the clock and your write permissions — then wait
one more tick.

---

## 🔍 Recon starter

Find what runs on a schedule, and **as whom**:

```bash
cat /etc/crontab 2>/dev/null
cat /etc/cron.d/* 2>/dev/null
ls -la /etc/cron.d /etc/cron.hourly /etc/cron.daily
crontab -l 2>/dev/null            # your own crontab (probably empty)
```

Every job here runs as `root`. For **each** file, directory, or command a job
touches, run the real test:

```bash
ls -la <that script>              # is it writable by me?
ls -ld <that directory>           # is the directory writable by me?
```

Anything a root job reaches for that **you can write** is a way in. (If you have
`pspy` from your kit, run it to watch cron fire in real time without root.)

---

## 🗺️ The five stations

Each is a different *class* of cron mistake. Figure out the attack from the name;
peek at a hint only if you're stuck.

| # | What you'll find | The lesson | Difficulty |
|---|------------------|-----------|:----------:|
| A | A root cron **script** that's world-writable | Edit the script, edit what root runs | ★☆☆☆ |
| B | A locked root script that **sources a writable config** | Inputs are code too (`source` runs it) | ★★☆☆ |
| C | A world-writable **directory** the cron executes | Anything you drop here runs as root | ★★☆☆ |
| D | A cron job that calls a command **by bare name** | Root trusting the cron's `$PATH` | ★★☆☆ |
| E | A cron `tar * ` backup over a **writable data dir** | Filenames can become arguments | ★★★☆ |

### Hints (open only when stuck)

<details><summary>Station A — world-writable cron script</summary>

Read `/etc/cron.d/*`. One job runs a script every minute as root. Now
`ls -la` that script. If its mode is `-rwxrwxrwx`, you can append to it. Whatever
you add runs as root on the next tick. A classic payload makes a root shell:
`cp /bin/bash /tmp/rootbash; chmod 6777 /tmp/rootbash`, then `/tmp/rootbash -p`.
</details>

<details><summary>Station B — writable config a root script sources</summary>

This script is root-owned and you *can't* edit it — but read what it does. It
`source`s (`.`) a config file. `ls -la` that config. `source` doesn't just read
values; it **executes** the file in the script's shell. So any shell command you
append to the config runs as root when the job next fires.
</details>

<details><summary>Station C — world-writable drop directory</summary>

A root job runs **every** `*.sh` in a directory. `ls -ld` that directory — it's
`0777`. You don't need to edit anything that exists; just **drop your own**
script there and wait for the sweep.
</details>

<details><summary>Station D — bare command in cron's PATH</summary>

Look closely at the cron entry — it sets its own `PATH=`, and the first directory
on it is writable by you. The job calls a command by **bare name** (no full
path). Put your own copy of that command in the writable dir that comes first in
`PATH`, and cron runs yours instead. (Same idea as Chapter 01's PATH hijack —
now on a timer.)
</details>

<details><summary>Station E — wildcard in a cron backup</summary>

A job runs something like `tar czf archive.tgz *` **inside** a directory you can
write to. The shell expands `*` to the filenames in that directory — and if a
filename *looks like a tar option*, tar treats it as one. Create files named
`--checkpoint=1` and `--checkpoint-action=exec=sh yourscript.sh`. Look up
"tar wildcard injection / `--checkpoint-action`".
</details>

---

## 🏁 Capture

When a path works, prove it:

```bash
id                 # expect uid=0(root) or euid=0(root)
cat /root/flag.txt # R2R{...}
```

Got the flag five different ways? You've *owned* cron. Write your blue-team
debrief, then move to the next host.

---

## 📖 Debrief (spoilers)

Full walkthrough of all five paths — with **how to detect** and **how to fix**
each — is in **[WRITEUP.md](WRITEUP.md)**. Try the box first; the debrief is worth
far more after you've struggled with it.
