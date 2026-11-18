# ============================================================================
#  Road to Root -- Chapter 08 : "Docker socket"
#  Host codename: hollow-forge-01   (compose service: target-docker)
#
#  Theme: membership of the `docker` group (or any read/write access to
#  /var/run/docker.sock) is root-equivalent. The Docker daemon runs as root, and
#  anyone who can talk to its socket can start a container that mounts the host
#  filesystem and chroots into it -- as root. No kernel bug, no SUID: the socket
#  IS the privilege.
#
#  This box runs its OWN Docker daemon (docker-in-docker) so the "host" you take
#  over is this container itself -- where /root/flag.txt lives. Needs the
#  container to be privileged (set in docker-compose.yml).
#  Foothold: labuser1 / password123   Goal: read /root/flag.txt
# ============================================================================
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        docker.io \
        busybox-static \
        curl jq \
        iptables \
        procps findutils coreutils iproute2 \
        less nano vim-tiny \
    && rm -rf /var/lib/apt/lists/*

# labuser1 is a normal user -- but in the `docker` group. That one line is the
# whole vulnerability: the group grants read/write on the root-owned socket.
RUN useradd -m -s /bin/bash labuser1 \
    && echo 'labuser1:password123' | chpasswd \
    && usermod -aG docker labuser1

# === PLANTED DOCKER-SOCKET VULNERABILITY ===================================
# Nothing to plant on the filesystem -- the "bug" is that labuser1 can reach the
# root daemon's socket. We bake an offline image (FROM scratch + static busybox)
# so `docker run` works with no registry/network: the entrypoint builds it once
# the inner daemon is up.
RUN mkdir -p /opt/innerimg \
    && cp /bin/busybox /opt/innerimg/busybox \
    && printf 'FROM scratch\nCOPY busybox /busybox\nENTRYPOINT ["/busybox"]\n' \
         > /opt/innerimg/Dockerfile
# THE MISTAKE: a low-privilege user in the `docker` group. The daemon is root,
#              so the user is effectively root via `docker run -v /:/host`.

# ===========================================================================

RUN printf 'R2R{the_d0cker_socket_is_root_equ1valent}\n' > /root/flag.txt \
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
