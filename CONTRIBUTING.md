# Contributing to Road to Root

Thanks for wanting to add to the range! This project teaches Linux privilege
escalation **hands-on** — so the bar for a contribution is simple: it has to
actually work, and it has to teach.

## Ground rules

1. **Every exploit must actually fire.** No path ships until you've run it
   end-to-end from `labuser1` to `root` and captured the flag. "It should work"
   is not good enough.
2. **Teach the fix, not just the break.** A lab isn't done until its writeup
   explains how a defender **detects** and **hardens** against it.
3. **One root cause per box.** A chapter teaches one idea well (multiple *paths*
   to root within that idea are great — they teach by comparison).
4. **Reset must be trivial:** `docker compose up --build --force-recreate <target>`
   returns the box to pristine-vulnerable.

## Adding a new lab

1. Read [`docs/LAB_TEMPLATE.md`](docs/LAB_TEMPLATE.md) — it defines the folder
   layout and the 7-part writeup every lab follows.
2. Create `targets/<name>/` with its `Dockerfile`, `entrypoint.sh`, a mission
   `README.md` (try-it-yourself) and a full `WRITEUP.md` (detect + harden + real-world).
3. Label the planted flaw in the Dockerfile between
   `# === PLANTED VULNERABILITY ===` fences so the source doubles as teaching material.
4. Plant the flag: `/root/flag.txt`, `root:root`, mode `600`, content `R2R{...}`.
5. Wire the service into `docker-compose.yml` and add a row to the roster in
   `README.md` + `docs/CAMPAIGN.md`.
6. Add a self-test under `tests/` (see `tests/verify_suid.sh`) and, ideally, a
   job in `.github/workflows/ci.yml` so the lab is verified on every push.

## Local development

```bash
make up          # build + start the attacker and target-suid
make attacker    # shell into the attacker box
make reset-suid  # rebuild the SUID target to pristine-vulnerable
make down        # tear the range down
```

## Running the tests

```bash
docker compose up -d --build target-suid
docker cp tests/verify_suid.sh target-suid:/tmp/
docker exec -u labuser1 target-suid bash /tmp/verify_suid.sh   # exits 0 if all paths reach root
```

## Conventions

- **Base image:** `ubuntu:24.04` unless a vuln needs otherwise.
- **Foothold account:** `labuser1 : password123` on every target.
- **Difficulty:** ★ (obvious) → ★★★★ (needs real understanding).
- Keep commits focused; open a draft PR early if you want feedback.

By contributing you agree your work is released under the repo's
[MIT License](LICENSE), and you confirm it's for **authorized, educational use**
(see [SECURITY.md](SECURITY.md)).
