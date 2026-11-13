# ============================================================================
#  Road to Root -- Chapter 03 : "The Trusted Shortcut"
#  Host codename: hollow-dmz-01   (compose service: target-sudo)
#
#  Theme: sudo privilege escalation -- FIVE independent paths to root in one box.
#  Every path is the same bargain: admins used sudo to delegate "small" bits of
#  root power, and every mistake made the delegation unsafe.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        build-essential \
        gcc \
        libc6-dev \
        findutils \
        gawk \
        coreutils \
        util-linux \
        iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# --- Low-privilege foothold account ----------------------------------------
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# Output dirs for the "admin workflows" the sudoers rules front
RUN mkdir -p /opt/admin /opt/backups /var/log/app

# === PLANTED SUDO VULNERABILITIES ==========================================
# Sudo itself is fine; every bug below lives in the sudoers RULES or in the
# commands those rules hand to the user. Each file under /etc/sudoers.d is
# correctly perm'd (0440 root:root) -- the mistake is always WHAT it grants.

# --- Station A -- GTFOBins: NOPASSWD on find -------------------------------
#   `find`'s -exec runs arbitrary commands. sudo'd find -> root shell.
#   exploit: sudo find . -maxdepth 0 -exec /bin/bash \;
RUN printf 'labuser1 ALL=(ALL) NOPASSWD: /usr/bin/find\n' \
         > /etc/sudoers.d/rtr-a-find \
    && chmod 0440 /etc/sudoers.d/rtr-a-find \
    && chown root:root /etc/sudoers.d/rtr-a-find
# THE MISTAKE: find's -exec lets any caller run anything -- see GTFOBins.

# --- Station B -- NOPASSWD on a world-writable script ----------------------
#   The "backup" script looks root-owned; its mode (0666) says otherwise.
#   Anyone can edit what sudo then runs as root.
#   exploit: overwrite /opt/admin/backup.sh, then sudo /opt/admin/backup.sh
RUN printf '#!/bin/bash\n# daily log backup -- runs as root via sudo\n/usr/bin/tar czf /opt/backups/logs.tgz /var/log 2>/dev/null\necho "backup complete"\n' \
         > /opt/admin/backup.sh \
    && chmod 0777 /opt/admin/backup.sh \
    && chown root:root /opt/admin/backup.sh
RUN printf 'labuser1 ALL=(ALL) NOPASSWD: /opt/admin/backup.sh\n' \
         > /etc/sudoers.d/rtr-b-script \
    && chmod 0440 /etc/sudoers.d/rtr-b-script \
    && chown root:root /etc/sudoers.d/rtr-b-script
# THE MISTAKE: a world-writable (0666) script granted to sudo. Sudo's own
#              perms are perfect; the script's aren't.

# --- Station C -- env_keep preserves LD_PRELOAD ----------------------------
#   Admin "fixed a tooling issue" by preserving LD_PRELOAD across sudo. The
#   dynamic loader then honors it for any non-SUID binary sudo runs -> your
#   shared object's constructor fires as root.
#   exploit: build a .so with __attribute__((constructor)), then:
#            sudo LD_PRELOAD=/tmp/pwn.so /usr/sbin/rtr-health
COPY src/rtr-health.c /tmp/rtr-health.c
RUN gcc -o /usr/sbin/rtr-health /tmp/rtr-health.c \
    && chown root:root /usr/sbin/rtr-health \
    && chmod 0755 /usr/sbin/rtr-health \
    && rm /tmp/rtr-health.c
RUN printf 'Defaults env_keep += "LD_PRELOAD"\nlabuser1 ALL=(ALL) NOPASSWD: /usr/sbin/rtr-health\n' \
         > /etc/sudoers.d/rtr-c-env \
    && chmod 0440 /etc/sudoers.d/rtr-c-env \
    && chown root:root /etc/sudoers.d/rtr-c-env
# THE MISTAKE: env_keep += "LD_PRELOAD". Any non-SUID binary sudo runs will
#              load an attacker-supplied shared object with root euid.

# --- Station D -- sudoers wildcard + writable directory + symlink ----------
#   `sudo cat /var/log/app/*.log` with /var/log/app world-writable lets you
#   place a symlink that cat happily follows anywhere root can read.
#   exploit: ln -s /root/flag.txt /var/log/app/pwn.log
#            sudo cat /var/log/app/pwn.log
RUN chmod 0777 /var/log/app
RUN printf 'labuser1 ALL=(ALL) NOPASSWD: /usr/bin/cat /var/log/app/*.log\n' \
         > /etc/sudoers.d/rtr-d-wildcard \
    && chmod 0440 /etc/sudoers.d/rtr-d-wildcard \
    && chown root:root /etc/sudoers.d/rtr-d-wildcard
# THE MISTAKE: a sudoers wildcard over a user-writable directory + a tool
#              that follows symlinks is a read-anywhere primitive.

# --- Station E -- command injection via eval in a sudoers'd script ---------
#   A "contact adder" eval's its argument. sudo runs it as root; argv flows
#   into eval; shell metacharacters escape to a root shell.
#   exploit: sudo /opt/admin/add-contact.sh 'bob; /bin/bash'
RUN printf '#!/bin/bash\n# add a contact to the list -- runs as root via sudo\n# usage: /opt/admin/add-contact.sh <name>\nNAME=$1\neval "echo Added: $NAME"\necho "$NAME" >> /opt/admin/contacts.txt 2>/dev/null\n' \
         > /opt/admin/add-contact.sh \
    && chmod 0755 /opt/admin/add-contact.sh \
    && chown root:root /opt/admin/add-contact.sh \
    && touch /opt/admin/contacts.txt \
    && chmod 0644 /opt/admin/contacts.txt \
    && chown root:root /opt/admin/contacts.txt
RUN printf 'labuser1 ALL=(ALL) NOPASSWD: /opt/admin/add-contact.sh *\n' \
         > /etc/sudoers.d/rtr-e-injection \
    && chmod 0440 /etc/sudoers.d/rtr-e-injection \
    && chown root:root /etc/sudoers.d/rtr-e-injection
# THE MISTAKE: unsanitized argv flowing into eval inside a sudo'd script.

# ===========================================================================

# --- The flag: proof of root. Only root can read it. -----------------------
RUN printf 'R2R{sud0_rules_rules_everything_around_me}\n' > /root/flag.txt \
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
