# Chapter 03 — "The Trusted Shortcut"  ·  Sudo Privilege Escalation

> **Host:** `hollow-dmz-01` (compose service `target-sudo`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★☆☆☆ → ★★★☆ (five paths, easy to medium-hard)

---

## 📻 Mission brief

Hollow Industries' DMZ host `hollow-dmz-01` is a workhorse: log pipeline,
nightly backups, a contact-list service, a handful of admin scripts. Over
time admins used `sudo` to delegate "small" bits of root power — let this
engineer run the backup, let ops cat a log, let the health team invoke a
diagnostic. Each grant was "safe". Each grant was also wrong.

Your foothold is `labuser1`. Enumerate what sudo will run for you, and turn
one of those shortcuts into a root shell.

> **The whole idea in one line:** when sudo grants you a command, it hands
> you root's authority for that command — and root's authority leaks
> everywhere the command (or its arguments, or its environment, or the files
> it touches) can reach.

---

## 🎯 Objective & rules of engagement

- **Win condition:** read `/root/flag.txt` (only root can). Flag format: `R2R{...}`.
- **In scope:** this container only. Everything you need is on the box.
- **Connect:** from the attacker box, `ssh labuser1@target-sudo` (password `password123`).
  Or jump straight in: `docker exec -it -u labuser1 target-sudo bash`.
- There are **five independent paths** to root. You need one to win; try all five.

---

## 🔍 Recon starter

Sudo's own diagnostic tool tells you what you're allowed to run:

```bash
sudo -l                            # what am I allowed to sudo?
cat /etc/sudoers.d/* 2>/dev/null   # raw drop-ins (if readable)
ls -la /opt/admin                  # the "admin workflow" dir
```

For each command or script `sudo -l` lists, ask:

1. Is it on **GTFOBins** with a "Sudo" entry?
2. Is the script it runs **writable** by me (or is its parent dir)?
3. Does any **`Defaults env_keep +=`** line preserve a dangerous var
   (`LD_PRELOAD`, `BASH_ENV`, `PYTHONPATH`, `PERL5LIB`)?
4. Does the command spec contain a **wildcard** (`*`) and reach into a
   directory I can write to?
5. Does the script interpolate **my argv** into a shell call (`eval`,
   `sh -c "$1"`, backticks)?

Each "yes" is a station.

---

## 🗺️ The five stations

| # | What you'll find | The lesson | Difficulty |
|---|------------------|-----------|:----------:|
| A | `NOPASSWD` on a tool with a documented sudo escape | GTFOBins "Sudo" column | ★☆☆☆ |
| B | `NOPASSWD` on a script that's **writable** by you | script perms matter, not just sudoers perms | ★★☆☆ |
| C | `Defaults env_keep += "LD_PRELOAD"` — sudo preserves it | env handling in sudo is a privilege boundary | ★★☆☆ |
| D | A sudoers **wildcard** command over a writable dir | sudo matches globs; tools follow symlinks | ★★☆☆ |
| E | A sudo'd script that `eval`s its argument | argv ≠ string; sanitize or don't shell out | ★★★☆ |

### Hints (open only when stuck)

<details><summary>Station A — NOPASSWD on a classic</summary>

`sudo -l` shows a tool you've seen a thousand times. Many "innocent-looking"
system binaries have a documented sudo-escape on **GTFOBins**: `find`, `awk`,
`vim`, `less`, `nano`, `env`, `man`, `sed`. Look up the exact binary there;
the `-exec` or `:!shell` pattern is the whole recipe.

</details>

<details><summary>Station B — writable script under sudoers</summary>

The sudoers entry points at a legitimate-looking admin script. The entry
itself is locked down (root-owned, 0440 under `/etc/sudoers.d/`). But
`ls -la` the SCRIPT the sudoers entry runs — is its mode `-rw-rw-rw-`?
If so, you write what sudo runs next.

</details>

<details><summary>Station C — env_keep + LD_PRELOAD</summary>

Run `sudo -l` and look at the **top** of the output (the `Defaults` lines).
`env_keep` tells sudo which environment variables to preserve across the
privilege transition. If `LD_PRELOAD` is in there, the dynamic linker will
honor your injected `.so` when sudo runs a **non-SUID** binary. Write a
tiny shared library with an `__attribute__((constructor))` function and
preload it.

</details>

<details><summary>Station D — wildcard + symlink</summary>

The sudoers entry has a `*` and points at a directory. Can you write in
that directory? If yes — sudo's wildcard matches files that *look like*
`*.log`, and tools like `cat` happily follow symlinks. Point a symlink
at the flag; sudo cats what it points to.

</details>

<details><summary>Station E — eval in a sudo'd script</summary>

Read the script the sudoers entry points at. If it uses `eval`, or passes
`$1` to a shell (`sh -c`, backticks, command substitution) without
careful quoting, your argument becomes shell code — executed as root.
The sudoers `*` in the command spec lets you pass any argv.

</details>

---

## 🏁 Capture

When a path works, prove it:

```bash
id                 # expect uid=0(root) or euid=0(root)
cat /root/flag.txt # R2R{...}
```

Got the flag five different ways? You've *owned* sudo. Write your
blue-team debrief, then move to the next host.

---

## 📖 Debrief (spoilers)

Full walkthrough of all five paths — with **how to detect** and **how to
fix** each — is in **[WRITEUP.md](WRITEUP.md)**. Try the box first; the
debrief is worth far more after you've struggled with it.
