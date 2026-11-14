# ============================================================================
#  Road to Root -- Chapter 04 : "PATH Hijacking"
#  Host codename: hollow-ops-01   (compose service: target-path)
#
#  Theme: PATH privilege escalation. Root calls a command by its short name.
#  The directory searched first is one labuser1 can write.
#  Stations A and B already live on the SUID and cron hosts. This image plants
#  the other three: a sudo wrapper, a service PATH, and /etc/environment.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        procps \
        findutils \
        coreutils \
        iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# === PLANTED PATH VULNERABILITIES ==========================================
# The commands root runs are root-owned and not writable. The mistake is the
# search path those commands use.

# --- Station C -- sudo wrapper sets PATH, then calls df by name ------------
#   secure_path still applies to the user's environment. It does not matter:
#   the script exports its own PATH, and the first directory is writable.
#   exploit: write /opt/admin/bin/df, then sudo /opt/admin/disk-check.sh
RUN mkdir -p /opt/admin/bin \
    && chmod 0777 /opt/admin/bin
COPY src/disk-check.sh /opt/admin/disk-check.sh
RUN chmod 0755 /opt/admin/disk-check.sh \
    && chown root:root /opt/admin/disk-check.sh \
    && printf 'labuser1 ALL=(ALL) NOPASSWD: /opt/admin/disk-check.sh\n' \
         > /etc/sudoers.d/rtr-c-path \
    && chmod 0440 /etc/sudoers.d/rtr-c-path \
    && chown root:root /etc/sudoers.d/rtr-c-path
# THE MISTAKE: a sudo script calls df with no slash, and a writable directory
#              is the first entry of the PATH that script sets.

# --- Station D -- unit file PATH, executed by the stand-in timer -----------
#   Docker does not boot systemd. rtr-unit-runner reads this unit every 20s
#   and does what systemd would: set Environment=PATH, then run ExecStart.
#   exploit: write /opt/svc/bin/df and wait for the next tick.
RUN mkdir -p /opt/svc/bin /etc/systemd/system /var/log/rtr \
    && chmod 0777 /opt/svc/bin
COPY src/disk-status.sh /opt/svc/disk-status.sh
COPY src/rtr-disk.service /etc/systemd/system/rtr-disk.service
RUN chmod 0755 /opt/svc/disk-status.sh \
    && chown root:root /opt/svc/disk-status.sh \
    && chmod 0644 /etc/systemd/system/rtr-disk.service \
    && chown root:root /etc/systemd/system/rtr-disk.service
# THE MISTAKE: the service PATH lists a writable directory before /usr/bin,
#              and ExecStart calls df by name.

# --- Station E -- /etc/environment is writable and a root job sources it ---
#   exploit: put your directory first in PATH, write uname there, wait a tick.
RUN mkdir -p /opt/maint
COPY src/env-report.sh /opt/maint/env-report.sh
RUN chmod 0755 /opt/maint/env-report.sh \
    && chown root:root /opt/maint/env-report.sh \
    && printf 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\n' \
         > /etc/environment \
    && chmod 0666 /etc/environment \
    && chown root:root /etc/environment
# THE MISTAKE: /etc/environment is mode 0666, and a root job sources it
#              before calling uname by name.

COPY src/rtr-unit-runner /usr/local/sbin/rtr-unit-runner
RUN chmod 0755 /usr/local/sbin/rtr-unit-runner \
    && chown root:root /usr/local/sbin/rtr-unit-runner

# ===========================================================================

RUN printf 'R2R{p4th_is_searched_left_to_right}\n' > /root/flag.txt \
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
