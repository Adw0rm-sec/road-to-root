# Road to Root

Hands-on Linux privilege escalation in Docker. You SSH in as `labuser1` and read `/root/flag.txt`.

[Walkthroughs](https://github.com/Adw0rm-sec/road-to-root/wiki) · [CI](https://github.com/Adw0rm-sec/road-to-root/actions/workflows/ci.yml) · MIT

## Start

```bash
git clone https://github.com/Adw0rm-sec/road-to-root
cd road-to-root
make up                          # attacker + Chapter 01
make attacker
ssh labuser1@target-suid         # password: password123
```

You are uid 1001. The flag is `/root/flag.txt`, mode `600`. One host has several paths. Any one of them is a win.

| Chapter | Start it | Ask this | A hit looks like |
|---|---|---|---|
| [01 SUID](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-01-Overview) | `make up` | Does a program become root when I run it? | `find / -perm -u=s -type f 2>/dev/null` lists something under `/usr/local` or `/opt`. The `s` in `-rwsr-xr-x` is the bit. Skip `sudo`, `su`, `passwd`, `mount`. |
| [02 Cron](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-02-Overview) | `make up-cron` | Does root run a file on a clock? | `ls -la /etc/cron.d` names a script, a config, a folder, a `PATH`, or `tar *` you can write. Wait for the next minute. |
| [03 Sudo](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-03-Overview) | `make up-sudo` | Will root run a command for me with no password? | `sudo -l` shows `(ALL) NOPASSWD:` and a path. Also read the `Defaults` lines for `env_keep`. |
| [04 PATH](https://github.com/Adw0rm-sec/road-to-root/wiki/Chapter-04-Overview) | `make up-path` | Does root call a command with no `/` in the name? | A writable directory is searched before `/usr/bin`. Your file with that command's name runs as root. |

Each chapter page links the stations. A station page is four short parts: how to spot it, what to run, why it works, how to fix it.

## Hosts

```bash
make up-cron            # target-cron
make up-sudo            # target-sudo
make up-path            # target-path
make reset-suid         # also reset-cron, reset-sudo, reset-path
make down
```

`ssh labuser1@target-cron`, `target-sudo`, or `target-path`. Same password. `docker exec -it -u labuser1 target-suid bash` skips the attacker hop.

## Still planned

Capabilities, a writable `/etc/passwd`, NFS `no_root_squash`, and the Docker socket. These containers share the host kernel, so kernel exploits are not labs here.

Run this only on your own machine. Do not put the containers on a network you do not control, and do not use the techniques on systems you are not allowed to test. [LICENSE](LICENSE).

Add a chapter with [docs/LAB_TEMPLATE.md](docs/LAB_TEMPLATE.md).
