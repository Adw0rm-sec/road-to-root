# ============================================================================
#  Road to Root -- Chapter 07 : "Local Service + Port Forwarding"
#  Host codename: hollow-relay-01   (compose service: target-pivot)
#
#  Theme: the privesc isn't ON the shell you landed -- it's a service bound to
#  127.0.0.1 that you can only reach by TUNNELLING to it. Redis is listening on
#  loopback, running as ROOT, with no password. From the attacker box you can't
#  touch it directly; forward a port through your SSH session and now you can.
#  Then Redis-as-root writes any file: an SSH key into /root, or a root cron.
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server openssh-client \
        redis-server \
        cron \
        curl \
        procps findutils coreutils iproute2 net-tools \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# === PLANTED "INTERNAL SERVICE" VULNERABILITIES ============================
# Two loopback-only services, two forwarding directions:
#   A  Redis as root on 127.0.0.1:6379 -> reach it with a LOCAL forward (-L),
#      make it write /root/.ssh/authorized_keys, ssh in as root.
#   B  a root "auto-updater" cron that fetches http://127.0.0.1:9000/payload.sh
#      -> nothing listens there; publish YOUR server onto the target's loopback
#      with a REMOTE forward (-R) and it runs your script as root.

# --- Station A -- Redis, no auth, running as root --------------------------
# Root's .ssh must exist for the authorized_keys write.
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
# Redis listens on 127.0.0.1 only; protected-mode off so a forwarded client
# (which arrives AS 127.0.0.1) can issue CONFIG/SET/SAVE. Started as root by the
# entrypoint -- that is the real mistake.
# enable-protected-configs: Redis 7.0 (2022) made `dir`/`dbfilename` protected,
# so CONFIG SET can't repoint the save file at runtime unless this is turned on.
# Legacy deploys (and plenty of older Redis in the wild) allow it by default --
# this lab opts in so you can practise the classic write primitive. The debrief
# explains the modern mitigation.
RUN printf 'bind 127.0.0.1\nport 6379\nprotected-mode no\ndaemonize no\ndir /var/lib/redis\nenable-protected-configs yes\nrdbcompression no\n' \
      > /etc/redis/redis-lab.conf \
    && mkdir -p /var/lib/redis
# Let root log in with the key Station A drops. Key only, no password.
RUN sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
# THE MISTAKE (A): a password-less Redis, bound to loopback, running as root.
#                  "Loopback-only" is defeated by an SSH local forward.

# --- Station B -- a root updater that trusts a loopback URL -----------------
# Every minute root fetches and runs a script from http://127.0.0.1:9000/.
# Nothing listens there by default, so the job is a no-op -- until you publish
# your OWN web server onto the target's loopback with `ssh -R 9000:...`.
RUN printf '* * * * * root /usr/bin/curl -fs --max-time 5 http://127.0.0.1:9000/payload.sh 2>/dev/null | /bin/bash >/dev/null 2>&1\n' \
      > /etc/cron.d/rtr-updater \
    && chmod 0644 /etc/cron.d/rtr-updater \
    && chown root:root /etc/cron.d/rtr-updater
# THE MISTAKE (B): a root job pulls code from a loopback port with no auth and
#                  pipes it to a shell. A remote forward puts an attacker there.

# ===========================================================================

RUN printf 'R2R{a_l00pback_service_is_one_ssh_dash_L_away}\n' > /root/flag.txt \
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
