#!/bin/bash
set -e
mkdir -p /var/run/sshd

# Start the INNER Docker daemon (docker-in-docker). vfs avoids the nested-
# overlayfs problem; this is a lab, not a perf test. The daemon runs as root --
# that is the privilege labuser1 borrows through the socket.
nohup dockerd --storage-driver=vfs >/var/log/dockerd.log 2>&1 &

# Wait for the socket, then bake the offline image so `docker run` needs no
# network, and make sure the `docker` group can use the socket.
for _ in $(seq 1 30); do
  [ -S /var/run/docker.sock ] && docker info >/dev/null 2>&1 && break
  sleep 1
done
if docker info >/dev/null 2>&1; then
  docker build -t rtr/bb /opt/innerimg >/var/log/innerimg.log 2>&1 || true
  # the socket is root:docker by default; make sure the group can reach it
  chgrp docker /var/run/docker.sock 2>/dev/null || true
  chmod 660 /var/run/docker.sock 2>/dev/null || true
fi

exec /usr/sbin/sshd -D -e
