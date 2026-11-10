# Lab Template

Every chapter in Road to Root is built from this template so the repo reads
as one coherent course. Copy this structure when adding a new target.

## Folder layout

```
targets/<name>/
├── Dockerfile        # base image + planted vulnerability (clearly commented)
├── entrypoint.sh     # starts whatever daemon the vuln needs, keeps box alive
├── src/              # (optional) C sources for custom vulnerable binaries
├── README.md         # MISSION BRIEF — story + objective + hints, NO full solution
└── WRITEUP.md        # DEBRIEF — full walkthrough, detection, hardening
```

Then add the service to `docker-compose.yml` and a row to the roster in the main
`README.md` + `docs/CAMPAIGN.md`.

---

## `README.md` (the mission brief) — sections

1. **Briefing** — 2–4 sentences of in-world framing. Why this host, why it matters.
2. **Objective** — the one-line goal: *become root, read `/root/flag.txt`*.
3. **Rules of engagement** — how to connect, credentials, what's in scope.
4. **Intel / Recon starter** — one or two commands to get them moving (not the answer).
5. **Objectives / stations** — the independent paths to root, described as goals
   ("there is a SUID interpreter on this box — abuse it"), not solutions.
6. **Hints** — progressive, inside `<details>` spoiler blocks so readers opt in.
7. **Capture** — what proves success (the flag).
8. **→ Debrief** — link to `WRITEUP.md`.

> The brief should let a motivated learner solve the box **without** the writeup.

---

## `WRITEUP.md` (the debrief) — one block per path to root

For **each** path, use this seven-part structure:

| Section | What it answers |
|---|---|
| **1. Recon** | How did we *find* this flaw? (exact commands + what to notice) |
| **2. The flaw** | What's the root cause, in one clear paragraph? |
| **3. Exploit** | Exact, copy-pasteable commands from `labuser1` → `root`. |
| **4. Why it works** | The mechanism. The *understanding*, not just the keystrokes. |
| **5. Detect** | How a defender spots it (commands, log lines, audit rules). |
| **6. Harden** | The fix, and the secure pattern that avoids it entirely. |
| **7. Real world** | A CVE, GTFOBins entry, or incident where this bit someone. |

End the writeup with a **"Clean up / reset"** note.

---

## Conventions

- **Base image:** `ubuntu:24.04` unless a vuln needs otherwise. Keep it small.
- **Foothold account:** `labuser1 : password123` on every target (consistency).
- **Flag:** `/root/flag.txt`, `root:root`, mode `600`, content `R2R{...}`.
- **Label planted flaws** in the Dockerfile between
  `# === PLANTED VULNERABILITY ===` fences so the source is self-documenting.
- **Difficulty:** ★ (obvious) → ★★★★ (needs real understanding), set per path and
  summarized per chapter.
- **Verify before publish:** run every path to `euid=0` and capture the flag. A
  path that hasn't been run end-to-end does not ship.
