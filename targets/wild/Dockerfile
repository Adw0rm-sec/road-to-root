# ============================================================================
#  Road to Root -- Chapter 06 : "Wildcard Expansion"
#  Host codename: hollow-archive-01   (compose service: target-wild)
#
#  Theme: argument injection through the shell wildcard `*`. When root runs a
#  command like `tar czf backup.tar *` in a directory you can write, the shell
#  expands `*` to the filenames BEFORE the program sees them -- so a file named
#  like an option BECOMES an option. Four tools, four injections, four roots.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
#
#  The clock is cron: every job fires once a minute.
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server openssh-client \
        cron \
        tar gzip rsync \
        procps findutils coreutils iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd \
    && useradd -m -s /bin/bash svcbackup \
    && echo 'svcbackup:x7_unused_x7' | chpasswd

RUN mkdir -p /opt/out /srv/incoming /var/log/rtr \
    && chown svcbackup:svcbackup /srv/incoming

# === PLANTED WILDCARD VULNERABILITIES ======================================
# Every cron ENTRY is correct (root-owned, 0644). The bug is always the same:
# an unquoted `*` in a directory a low-privilege user can write to.

# --- Station A -- tar wildcard (--checkpoint-action=exec) -> RCE ------------
#   Root runs `tar czf ... *` in /opt/archive (0777). Filenames that look like
#   tar options become options. --checkpoint-action=exec runs a command.
#   exploit: plant --checkpoint=1, --checkpoint-action=exec=sh runme.sh, runme.sh
RUN mkdir -p /opt/archive \
    && printf 'placeholder\n' > /opt/archive/readme.txt \
    && printf '#!/bin/bash\ncd /opt/archive && /usr/bin/tar czf /opt/out/archive.tgz * >/dev/null 2>&1\n' \
         > /usr/local/sbin/archive-run.sh \
    && chmod 0755 /usr/local/sbin/archive-run.sh \
    && chmod 0777 /opt/archive \
    && printf '* * * * * root /usr/local/sbin/archive-run.sh\n' > /etc/cron.d/rtr-archive \
    && chmod 0644 /etc/cron.d/rtr-archive
# THE MISTAKE: `tar czf ... *` with an unquoted wildcard in a writable dir.

# --- Station B -- rsync wildcard (-e remote shell) -> RCE ------------------
#   Root backs up /opt/sync/* to svcbackup@localhost over ssh. A file named
#   `-e sh payload.sh` becomes rsync's -e (remote-shell) option; rsync runs it
#   LOCALLY as root to start the transfer.
#   exploit: plant `-e sh payload.sh` and payload.sh in /opt/sync.
RUN mkdir -p /opt/sync \
    && printf 'placeholder\n' > /opt/sync/readme.txt \
    && printf '#!/bin/bash\ncd /opt/sync && /usr/bin/rsync -a * svcbackup@localhost:/srv/incoming/ >/dev/null 2>&1\n' \
         > /usr/local/sbin/sync-run.sh \
    && chmod 0755 /usr/local/sbin/sync-run.sh \
    && chmod 0777 /opt/sync \
    && printf '* * * * * root /usr/local/sbin/sync-run.sh\n' > /etc/cron.d/rtr-sync \
    && chmod 0644 /etc/cron.d/rtr-sync
# THE MISTAKE: `rsync -a * host:` with an unquoted wildcard in a writable dir.
# Root's passwordless ssh key to svcbackup@localhost is planted in entrypoint.

# --- Station C -- chown --reference wildcard -> own a root script -----------
#   /opt/pipeline is STICKY (1777): you can create files but not delete or edit
#   root's. Root runs `chown -R root:root *` then executes process.sh. A planted
#   `--reference=<your file>` overrides root:root and hands you process.sh.
#   exploit: plant --reference=/home/labuser1/ref; after the chown flips
#            process.sh to you, write your payload into it; next tick runs it.
RUN mkdir -p /opt/pipeline \
    && printf '#!/bin/bash\n# data pipeline step -- runs as root via cron\n: pipeline ok\n' \
         > /opt/pipeline/process.sh \
    && chown root:root /opt/pipeline/process.sh \
    && chmod 0755 /opt/pipeline/process.sh \
    && printf '#!/bin/bash\ncd /opt/pipeline && /usr/bin/chown -R root:root * 2>/dev/null; /bin/bash /opt/pipeline/process.sh 2>/dev/null\n' \
         > /usr/local/sbin/pipeline-run.sh \
    && chmod 0755 /usr/local/sbin/pipeline-run.sh \
    && chmod 1777 /opt/pipeline \
    && printf '* * * * * root /usr/local/sbin/pipeline-run.sh\n' > /etc/cron.d/rtr-pipeline \
    && chmod 0644 /etc/cron.d/rtr-pipeline
# THE MISTAKE: `chown -R root:root *` in a sticky, user-writable dir, next to a
#              root script the same job executes. --reference flips ownership.

# --- Station D -- chmod --reference wildcard -> loosen a root script --------
#   Same shape, mode instead of owner. /opt/conf is STICKY (1777). hook.sh is
#   root:root 0700 (you can't read or edit it). Root runs `chmod -R 700 *` then
#   executes hook.sh. A planted `--reference=<world-writable file>` overrides
#   700 and makes hook.sh world-writable.
#   exploit: plant a 0666 file + `--reference=<it>`; after the chmod opens
#            hook.sh, write your payload; next tick runs it as root.
RUN mkdir -p /opt/conf \
    && printf '#!/bin/bash\n# post-config hook -- runs as root via cron\n: hook ok\n' \
         > /opt/conf/hook.sh \
    && chown root:root /opt/conf/hook.sh \
    && chmod 0700 /opt/conf/hook.sh \
    && printf '#!/bin/bash\ncd /opt/conf && /usr/bin/chmod -R 700 * 2>/dev/null; /bin/bash /opt/conf/hook.sh 2>/dev/null\n' \
         > /usr/local/sbin/conf-run.sh \
    && chmod 0755 /usr/local/sbin/conf-run.sh \
    && chmod 1777 /opt/conf \
    && printf '* * * * * root /usr/local/sbin/conf-run.sh\n' > /etc/cron.d/rtr-conf \
    && chmod 0644 /etc/cron.d/rtr-conf
# THE MISTAKE: `chmod -R 700 *` in a sticky, user-writable dir, next to a root
#              script the same job executes. --reference overrides the mode.

# ===========================================================================

RUN printf 'R2R{the_shell_expands_star_before_the_program_sees_it}\n' > /root/flag.txt \
    && chown root:root /root/flag.txt \
    && chmod 600 /root/flag.txt

COPY motd /etc/motd
COPY MISSION.txt /home/labuser1/MISSION.txt
RUN chown labuser1:labuser1 /home/labuser1/MISSION.txt

RUN mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
