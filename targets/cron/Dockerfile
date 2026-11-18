# ============================================================================
#  Road to Root -- Chapter 02 : "The 60-Second Window"
#  Host codename: hollow-backup-01   (compose service: target-cron)
#
#  Theme: cron privilege escalation -- FIVE independent paths to root in one box.
#  Every path is the same bargain: root's cron runs something you can influence,
#  once a minute. You plant, you wait <=60 seconds, root does your bidding.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:25.10

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        cron \
        tar gzip \
        procps \
        iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# --- Low-privilege foothold account ----------------------------------------
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# Output dirs the "backup / maintenance" jobs write to (root-owned)
RUN mkdir -p /opt/backups /var/log/rtr

# === PLANTED CRON VULNERABILITIES ==========================================
# Each station is a root cron job that runs every minute and trusts something a
# low-privilege user can write. The cron ENTRIES themselves are correct
# (root-owned, 0644); the mistake is always in WHAT the job touches.

# --- Station A -- world-writable cron SCRIPT -------------------------------
#   The script root runs every minute is itself world-writable (0777).
#   exploit: append your commands to /opt/maint/rotate.sh, wait <=60s.
RUN mkdir -p /opt/maint \
    && printf '#!/bin/bash\n# log tidy -- runs as root via cron\n/usr/bin/find /var/log -type f -name "*.old" -delete 2>/dev/null\n' \
         > /opt/maint/rotate.sh \
    && chmod 0777 /opt/maint/rotate.sh \
    && printf '* * * * * root /opt/maint/rotate.sh\n' > /etc/cron.d/rtr-rotate \
    && chmod 0644 /etc/cron.d/rtr-rotate
# THE MISTAKE: chmod 777 on a script that root executes.

# --- Station B -- world-writable CONFIG sourced by a locked root script -----
#   The script is root-owned & 0755 (you cannot edit it), but it `source`s a
#   world-writable config -- and `source` EXECUTES whatever is in that file.
#   exploit: append your commands to /etc/rtr/backup.conf, wait <=60s.
RUN mkdir -p /etc/rtr \
    && printf 'SRC=/var/log\nDEST=/opt/backups/logs.tgz\n' > /etc/rtr/backup.conf \
    && chmod 0666 /etc/rtr/backup.conf \
    && printf '#!/bin/bash\n# site backup -- settings live in /etc/rtr/backup.conf\n. /etc/rtr/backup.conf\n/usr/bin/tar czf "${DEST:-/opt/backups/logs.tgz}" "${SRC:-/var/log}" >/dev/null 2>&1\n' \
         > /usr/local/sbin/backup-run.sh \
    && chmod 0755 /usr/local/sbin/backup-run.sh \
    && printf '* * * * * root /usr/local/sbin/backup-run.sh\n' > /etc/cron.d/rtr-backup \
    && chmod 0644 /etc/cron.d/rtr-backup
# THE MISTAKE: the script is locked down, but the config it `source`s is 0666.

# --- Station C -- world-writable DROP directory the cron executes -----------
#   A root cron runs every *.sh it finds in /opt/jobs. That directory is 0777,
#   so anything you drop there runs as root.
#   exploit: drop a script in /opt/jobs/, wait <=60s.
RUN mkdir -p /opt/jobs \
    && printf '#!/bin/bash\n: heartbeat\n' > /opt/jobs/00-heartbeat.sh \
    && chmod 0755 /opt/jobs/00-heartbeat.sh \
    && printf '#!/bin/bash\n# run every maintenance job in the drop dir, as root\nfor s in /opt/jobs/*.sh; do [ -r "$s" ] && /bin/bash "$s"; done\n' \
         > /usr/local/sbin/run-jobs.sh \
    && chmod 0755 /usr/local/sbin/run-jobs.sh \
    && chmod 0777 /opt/jobs \
    && printf '* * * * * root /usr/local/sbin/run-jobs.sh\n' > /etc/cron.d/rtr-jobs \
    && chmod 0644 /etc/cron.d/rtr-jobs
# THE MISTAKE: a world-writable directory whose contents root executes.

# --- Station D -- $PATH hijack in the cron environment ----------------------
#   The cron sets PATH with a world-writable dir FIRST, and the job calls a
#   command by bare name ('df'). Drop your own 'df' earlier in PATH.
#   exploit: place a malicious /opt/maint/bin/df on the box, wait <=60s.
RUN mkdir -p /opt/maint/bin \
    && printf '#!/bin/bash\n# disk health report -- runs as root via cron\ndf -h > /var/log/rtr/disk.log 2>&1\n' \
         > /usr/local/sbin/health-report.sh \
    && chmod 0755 /usr/local/sbin/health-report.sh \
    && chmod 0777 /opt/maint/bin \
    && printf 'PATH=/opt/maint/bin:/usr/bin:/bin\n* * * * * root /usr/local/sbin/health-report.sh\n' \
         > /etc/cron.d/rtr-health \
    && chmod 0644 /etc/cron.d/rtr-health
# THE MISTAKE: a writable dir placed first on the cron job's PATH + a bare command.

# --- Station E -- wildcard injection in a cron backup -----------------------
#   A root cron runs `tar czf ... *` inside a world-writable data dir. Filenames
#   that look like tar options BECOME tar options -> --checkpoint-action runs code.
#   exploit: drop crafted filenames in /opt/data, wait <=60s.
RUN mkdir -p /opt/data \
    && printf 'placeholder\n' > /opt/data/readme.txt \
    && printf '#!/bin/bash\n# archive the data dir -- runs as root via cron\ncd /opt/data && /usr/bin/tar czf /opt/backups/data.tgz * >/dev/null 2>&1\n' \
         > /usr/local/sbin/archive.sh \
    && chmod 0755 /usr/local/sbin/archive.sh \
    && chmod 0777 /opt/data \
    && printf '* * * * * root /usr/local/sbin/archive.sh\n' > /etc/cron.d/rtr-archive \
    && chmod 0644 /etc/cron.d/rtr-archive
# THE MISTAKE: `tar *` with an unquoted wildcard in a user-writable directory.

# ===========================================================================

# --- The flag: proof of root. Only root can read it. -----------------------
RUN printf 'R2R{cr0n_runs_what_you_can_wr1te_m1nd_the_perms}\n' > /root/flag.txt \
    && chown root:root /root/flag.txt \
    && chmod 600 /root/flag.txt

# --- In-world mission briefing (shown on SSH login) ------------------------
COPY motd /etc/motd
COPY MISSION.txt /home/labuser1/MISSION.txt
RUN chown labuser1:labuser1 /home/labuser1/MISSION.txt

RUN mkdir -p /var/run/sshd
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
