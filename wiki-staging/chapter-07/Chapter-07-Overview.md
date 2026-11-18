# Chapter 07 — "Local Service + Port Forwarding"

> **Host:** `hollow-relay-01` (compose service `target-pivot`)
> **Foothold:** `labuser1 : password123` · **Objective:** root, read `/root/flag.txt`
> **Difficulty:** ★★★☆
> **Flag:** `/root/flag.txt` → `R2R{a_l00pback_service_is_one_ssh_dash_L_away}`

New to the range? Read [[Getting-Started]] and [[How-A-Chapter-Works]] first.

## Mission brief

`sudo -l` is empty; no odd SUID, no capabilities. Host enumeration is a dead
end because the vulnerable thing isn't a file — it's a **service** bound to
`127.0.0.1`. The admins assumed loopback-only meant unreachable. It doesn't: a
shell plus SSH port forwarding dissolves that boundary, and the service behind
it is exploitable for **code execution as root**.

> **The whole idea in one line:** a service on `127.0.0.1` is not safe from
> someone with a shell — `ssh -L` turns the target's loopback into *your*
> loopback, and `ssh -R` turns *your* service into one on the target's loopback.

## Recon starter

```bash
ss -tlnp                      # (or netstat -tlnp) — what listens, on which iface
# 127.0.0.1:8080 -> an internal web app, loopback only
cat /etc/cron.d/rtr-updater   # a root job that fetches from a loopback port
```

## Forwarding in three directions

```bash
ssh -L 8080:127.0.0.1:8080 labuser1@target-pivot   # pull target's loopback to you
ssh -R 9000:127.0.0.1:8000 labuser1@target-pivot   # push your service to the target
ssh -D 1080 labuser1@target-pivot                  # SOCKS proxy for a whole subnet
```

No SSH on the box? **chisel** and **socat** do the same `-L`/`-R` forwards.

## The two stations — both RCE as root

| # | Forward | Service | Win | Difficulty |
|---|---|---|---|:---:|
| [[A\|C07-Station-A-local-forward-webapp]] | `-L` local | a root web app on `127.0.0.1:8080` | command injection in `/ping?host=` → RCE as root | ★★★☆ |
| [[B\|C07-Station-B-remote-forward-updater]] | `-R` remote | a root updater fetching `http://127.0.0.1:9000/` | publish your script there → root runs it | ★★★☆ |

## How to connect / reset

```bash
make up-pivot
make attacker
# from the attacker box:
ssh labuser1@target-pivot       # password123
# ...
make reset-pivot
```

## The through-line

Loopback binding is not an access control: firewall and authenticate internal
services as if they were exposed, don't run them as root, don't build shell
commands from user input, and lock down SSH forwarding where it isn't needed.
Detection and fixes in [[Blue-Team-Playbook]]; the repo debrief is
[`targets/pivot/WRITEUP.md`](https://github.com/Adw0rm-sec/road-to-root/blob/main/targets/pivot/WRITEUP.md).

## Next

Start with [[C07-Station-A-local-forward-webapp]].
