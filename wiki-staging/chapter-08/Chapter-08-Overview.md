# Chapter 08 — "Docker socket"

> **Host:** `hollow-forge-01` (compose service `target-docker`)
> **Foothold:** `labuser1 : password123` · **Objective:** root, read `/root/flag.txt`
> **Difficulty:** ★★★☆
> **Flag:** `/root/flag.txt` → `R2R{the_d0cker_socket_is_root_equ1valent}`

New to the range? Read [[Getting-Started]] and [[How-A-Chapter-Works]] first.

## Mission brief

The build host put `labuser1` in the `docker` group so CI could run containers.
That one line is the vulnerability. The Docker daemon runs **as root** and
listens on `/var/run/docker.sock`; anyone who can talk to it can start a
container that **bind-mounts the host filesystem** and runs as root inside it.

> **The whole idea in one line:** `docker run -v /:/host …` hands you the host's
> root filesystem as root — so `docker` group ≈ `root`. No kernel bug, no SUID;
> the socket *is* the privilege.

This box runs its **own** inner daemon (docker-in-docker), so the "host" you take
over is this container, where the flag lives.

## Recon starter

```bash
id                              # groups=...,docker
ls -l /var/run/docker.sock      # srw-rw---- root docker
docker images                   # rtr/bb is baked in (the box is airgapped)
```

## The three stations

| # | Technique | Proves | Difficulty |
|---|---|---|:---:|
| [[A\|C08-Station-A-mount-chroot]] | `docker run -v /:/host rtr/bb chroot /host cat …` | read any file as root | ★★☆☆ |
| [[B\|C08-Station-B-persistence]] | mount `/`, write a SUID root `bash` / SSH key | **persistent** root | ★★★☆ |
| [[C\|C08-Station-C-raw-socket-api]] | the socket's HTTP API with `curl`, no `docker` client | the **socket**, not the CLI, is the bug | ★★★☆ |

## How to connect / reset

```bash
make up-docker          # privileged container (runs its own dockerd)
make attacker
ssh labuser1@target-docker      # password123
# ...
make reset-docker
```

## The through-line

Treat `docker` group membership as granting root. Never mount `docker.sock`
into an untrusted container; prefer rootless Docker/Podman, a socket-proxy, and
`userns-remap`. It's configuration, not a patch — the behaviour is
intended. Detection and fixes in [[Blue-Team-Playbook]]; the repo debrief is
[`targets/docker/WRITEUP.md`](https://github.com/Adw0rm-sec/road-to-root/blob/main/targets/docker/WRITEUP.md).

## Next

Start with [[C08-Station-A-mount-chroot]].
