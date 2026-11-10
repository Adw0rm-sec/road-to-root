# Road to Root — Campaign Bible

> The story is a wrapper. The skills are real. Every "mission" below is a
> genuine Linux privilege-escalation technique you'll meet on real engagements
> and in CTFs. The fiction just gives you a reason to care who's root.

---

## Dramatis personae

- **You** — *"Operator"*, a red-team contractor.
- **BlackReef Security** — the firm you work for. Hired by the client to simulate
  a real attacker.
- **Hollow Industries** — the client. A mid-size logistics & data company with the
  usual sins: overworked admins, convenience hacks left in production, and nobody
  reading the audit logs.

## The premise

The engagement rules of engagement (RoE) are simple and already signed:

> *"Assume breach. Phishing succeeded — you have a standard user account on
> several internal hosts. Demonstrate what a real attacker could do next.
> Prove every root compromise by capturing the host flag. Write it up so our
> blue team can detect and fix it."*

So you never have to find the foothold — you're handed `labuser1 / password123`.
The campaign is entirely about **what happens after the foothold**: the climb
from user to root, one host, one root cause at a time.

## How a chapter works

Every host in the range is self-contained and follows the same loop:

1. **Briefing** — the in-world reason this box matters (in the lab's `README.md`).
2. **Recon** — you enumerate; the box has one *class* of flaw with several
   independent paths to root (so you can fail one and still win).
3. **Escalate** — you exploit a path and become root.
4. **Capture the flag** — `/root/flag.txt`, readable only by root. Format:
   `R2R{...}`. Reading it = mission complete.
5. **Debrief** — the `WRITEUP.md` shows every path, plus **detection** and
   **hardening** for the blue-team report.

## Chapter log

### Chapter 01 — "Set & Forget" · `hollow-fileproc-01` (`target-suid`)
The file-processing jump box. Over the years, admins and a couple of devs left a
trail of **SUID** convenience hacks: a SUID `find` from a 2am incident, a SUID
`python3` from a deploy script, and two homegrown root tools that trust things
they shouldn't. Five independent SUID paths, one flag. **This is where you learn
to spot the `-rws` bit and never look at a file listing the same way again.**

### Chapter 02 — "The 60-Second Window" · `hollow-backup-01` (`target-cron`)
*(draft)* A root cron job runs a world-writable backup script every minute. Patience
and one `echo` away from root.

### Chapters 03–08
Planned. See the roster in the main [README](../README.md). Each lands only after
it's been built and verified locally.

---

## Design principles (for contributors & future-you)

- **One root cause per box.** A lab teaches *one* idea well. Multiple *paths* to
  root within that idea are encouraged (you learn by comparison).
- **The flaw is always a plausible human mistake**, labelled in the Dockerfile as
  `PLANTED VULNERABILITY` so the source doubles as teaching material.
- **Every exploit must actually fire.** No path ships until it's been run end-to-end
  and reaches `euid=0`.
- **Teach the fix, not just the break.** A path to root isn't done until the
  writeup explains detection and hardening.
- **Reset must be trivial.** `docker compose up --build --force-recreate <target>`
  returns any box to pristine-vulnerable.
