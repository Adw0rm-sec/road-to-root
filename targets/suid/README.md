# Chapter 01 — "Set & Forget"  ·  SUID Privilege Escalation

> **Host:** `hollow-fileproc-01` (compose service `target-suid`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★☆☆☆ → ★★★☆ (five paths, easy to medium)

---

## 📻 Mission brief

Phishing landed you a standard account on Hollow Industries' file-processing jump
box. It shuffles log and report files all day, and successive admins kept
"fixing" things at 2am with the fastest hack available — usually a `chmod`. Those
hacks never got reverted.

Intel says this box leans on **SUID binaries**. A SUID binary runs with its
**owner's** privileges, not yours — and several here are owned by `root`. Find
them. Make them work for you. Get root.

> **The whole idea in one line:** when a program owned by root has the `-rws-`
> bit set, *running it is running root's code* — so if you can influence what it
> does, you influence what root does.

---

## 🎯 Objective & rules of engagement

- **Win condition:** read `/root/flag.txt` (only root can). Flag format: `R2R{...}`.
- **In scope:** this container only. Everything you need is on the box.
- **Connect:** from the attacker box, `ssh labuser1@target-suid` (password `password123`).
  Or jump straight in: `docker exec -it -u labuser1 target-suid bash`.
- There are **five independent paths** to root. You need one to win; try to map all five.

---

## 🔍 Recon starter

Your first job on any box is to find what runs as someone more powerful than you.
For SUID, that's one command:

```bash
find / -perm -4000 -type f 2>/dev/null
```

Everything in that list owned by `root` is a candidate. For each one, ask:
*"this runs as root — what can I make it do?"*

Some entries are normal (`sudo`, `passwd`, `mount`…). A few on this box are **not**
normal. Those are your way in.

---

## 🗺️ The five stations

Each is a different *class* of SUID mistake. Figure out the attack from the name;
peek at a hint only if you're stuck.

| # | What you'll find | The lesson | Difficulty |
|---|------------------|-----------|:----------:|
| A | A SUID copy of a well-known system tool | Known binaries have known tricks | ★☆☆☆ |
| B | A SUID copy of a scripting interpreter | An interpreter runs *your* code as root | ★☆☆☆ |
| C | A custom root tool that calls a command **by bare name** | Root trusting your `$PATH` | ★★☆☆ |
| D | A custom root tool that **takes your input** | Root pasting your text into a shell | ★★☆☆ |
| E | A custom root tool that **loads a plugin** from a writable dir | Root loading your library | ★★★☆ |

### Hints (open only when stuck)

<details><summary>Station A — SUID system tool</summary>

It's a renamed copy of a classic enumeration tool. Many standard binaries have a
documented "if this is SUID, here's your root shell" recipe. Where would you look
that up by binary name? (Think: **GTFOBins**.) The flag `-exec` and keeping
privileges with `-p` matter.
</details>

<details><summary>Station B — SUID interpreter</summary>

If an *interpreter* runs as root, it'll happily run whatever **you** write. You
don't need a trick in a file — you can pass code on the command line. What two
things must your code do to (a) nail down root and (b) hand you a shell?
</details>

<details><summary>Station C — bare command name</summary>

Run the tool and watch *which* helper command it calls. It calls it **without a
full path**. Who decides where a bare command name is found? You do — via `$PATH`.
Put your own version of that command somewhere early in `$PATH`.
</details>

<details><summary>Station D — your input reaches a shell</summary>

The tool builds a shell command out of the argument you give it, with no
sanitising. Shell metacharacters are your friend here: `;`, `|`, `$(...)`.
What happens if your "filename" is `something; /bin/bash`?
</details>

<details><summary>Station E — loadable plugin</summary>

The tool loads a shared library (`.so`) at runtime from a specific directory.
Check that directory's permissions (`ls -ld`). If you can write there, you can
replace the library with your own — and a library can run code the instant it's
loaded (`__attribute__((constructor))`). Note: `LD_PRELOAD` is *ignored* for SUID
binaries, so you must replace the actual file it loads.
</details>

---

## 🏁 Capture

When a path works, prove it:

```bash
id                 # expect uid=0(root) or euid=0(root)
cat /root/flag.txt # R2R{...}
```

Got the flag five different ways? You've *owned* SUID. Write your blue-team
debrief, then move to the next host.

---

## 📖 Debrief (spoilers)

Full walkthrough of all five paths — with **how to detect** and **how to fix**
each — is in **[WRITEUP.md](WRITEUP.md)**. Try the box first; the debrief is worth
far more after you've struggled with it.
