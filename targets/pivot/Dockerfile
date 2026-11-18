# ============================================================================
#  Road to Root -- Chapter 07 : "Local Service + Port Forwarding"
#  Host codename: hollow-relay-01   (compose service: target-pivot)
#
#  Theme: the privesc isn't ON the shell you landed -- it's a service bound to
#  127.0.0.1 that you can only reach by TUNNELLING to it. Two internal services,
#  two forwarding directions, both ending in code execution AS ROOT:
#    A  an internal "diagnostics" web app on 127.0.0.1:8080 with a command-
#       injection bug, running as root -> reach it with a LOCAL forward (-L).
#    B  a root "updater" cron that fetches http://127.0.0.1:9000/payload.sh ->
#       publish YOUR server onto the target's loopback with a REMOTE forward (-R).
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server openssh-client \
        python3 \
        cron \
        curl \
        iputils-ping \
        procps findutils coreutils iproute2 net-tools \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd

# === PLANTED "INTERNAL SERVICE" VULNERABILITIES ============================
# Two loopback-only services, two forwarding directions. Both give RCE as root.

# --- Station A -- internal diagnostics web app, command injection, runs as root
#   Bound to 127.0.0.1:8080. /ping?host= splices host into a shell command.
#   Reach it with `ssh -L 8080:127.0.0.1:8080` and inject -> RCE as root.
RUN mkdir -p /opt/intranet
COPY src/intranet.py /opt/intranet/intranet.py
RUN chmod 0755 /opt/intranet/intranet.py \
    && chown root:root /opt/intranet/intranet.py
# THE MISTAKE (A): a root web service on loopback that shells out with
#                  unsanitised input -- "loopback-only" is defeated by -L.

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
