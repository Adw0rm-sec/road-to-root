#!/bin/bash
set -e
mkdir -p /var/run/sshd /var/lib/redis

# The internal service: Redis as ROOT, bound to loopback, no auth.
# (Running it as root is the vulnerability the chapter is about.)
redis-server /etc/redis/redis-lab.conf --daemonize yes

# cron must run for the Station B (root cron) payload to fire.
service cron start || cron

exec /usr/sbin/sshd -D -e
